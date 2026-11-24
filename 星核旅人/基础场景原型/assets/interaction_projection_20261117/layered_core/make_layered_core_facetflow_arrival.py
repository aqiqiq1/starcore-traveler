#!/usr/bin/env python3
"""Build the face-following activation arrival map for the L2 crystal.

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_layered_core_facetflow_arrival.py

Output:
  layered_core_facetflow_arrival_256x32.png
      R = normalized arrival time (0..1-arrival_window), A = exposed lower mask.
      Not a colour texture; approved crystal PNGs are untouched.
  manifest_facetflow_20261118.json
      hashes, triangle/seed provenance, source faces, arrival stats, window.

The same SEED/point set/Delaunay triangulation as the approved generator is
reproduced here. Arrival starts at top-contact faces with a smooth x-stagger,
propagates through actual triangle adjacency (Dijkstra), is averaged onto shared
vertices, and is barycentrically interpolated inside each triangle. That keeps
the field continuous across facet edges and makes the light travel through
connected facets, not a straight row-wide wipe. No approved colour/facet asset
or generator output is modified.
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
ROOF = PROJECT / "assets" / "level02_conductive_stone" / "conductive_roof_256x32.png"
INACTIVE = HERE / "layered_core_approved_inactive_256x32.png"
ACTIVE = HERE / "layered_core_approved_active_256x32.png"
MASK = HERE / "layered_core_approved_mask_256x32.png"
OUT = HERE / "layered_core_facetflow_arrival_256x32.png"
MANIFEST = HERE / "manifest_facetflow_20261118.json"

W, H = 256, 32
SEED = 20261118
ARRIVAL_WINDOW = 0.16 / 0.7  # 0.16 s soft arrival window on the 0.7 s clock
MAX_ARRIVAL = 1.0 - ARRIVAL_WINDOW
SUPER = [(-1000.0, -1000.0), (3000.0, -1000.0), (-1000.0, 3000.0)]


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
    return (a * (1.0 - fx) + b * fx) * (1.0 - fy) + (c * (1.0 - fx) + d * fx) * fy


# Copied from the approved generator: same point seed/order and Delaunay rules.
def build_points(rng: random.Random) -> list[tuple[float, float]]:
    pts: list[tuple[float, float]] = [
        (-8.0, 13.0), (W + 8.0, 13.0), (W + 8.0, H + 3.0), (-8.0, H + 3.0),
    ]
    attempts = 0
    while len(pts) < 74 and attempts < 5000:
        attempts += 1
        x = rng.uniform(-4.0, W + 4.0)
        y = rng.uniform(15.0, H + 2.0)
        radius = rng.uniform(5.0, 10.0)
        ok = True
        for (px, py) in pts[4:]:
            if (x - px) ** 2 + (y - py) ** 2 < radius * radius:
                ok = False
                break
        if ok:
            pts.append((x, y))
    for _ in range(14):
        px, py = pts[rng.randrange(4, len(pts))]
        ang = rng.uniform(0.0, math.tau)
        dist = rng.uniform(3.0, 5.4)
        pts.append((px + math.cos(ang) * dist, py + math.sin(ang) * dist))
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


def delaunay(points: list[tuple[float, float]]) -> list[tuple[int, int, int]]:
    allp = points + SUPER
    n = len(points)
    tris: list[tuple[int, int, int]] = [(n, n + 1, n + 2)]
    for pi in range(n):
        p = allp[pi]
        bad: list[tuple[int, int, int]] = []
        for tri in tris:
            cc = circumcircle(allp[tri[0]], allp[tri[1]], allp[tri[2]])
            if cc is None:
                continue
            ux, uy, r2 = cc
            if (p[0] - ux) ** 2 + (p[1] - uy) ** 2 <= r2 + 1e-7:
                bad.append(tri)
        edges: dict[tuple[int, int], tuple[int, int]] = {}
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


def triangle_at(px: float, py: float, tris, pts) -> int:
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


def barycentric(p: tuple[float, float], a, b, c) -> tuple[float, float, float]:
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


def build():
    root = Image.open(ROOF).convert("RGBA")
    assert root.size == (W, H)
    mask = Image.open(MASK).convert("RGBA")
    assert mask.size == (W, H)
    mp = mask.load()

    rng = random.Random(SEED)
    pts = build_points(rng)
    tris = delaunay(pts)
    ntri = len(tris)

    tri_pixels: list[list[tuple[int, int]]] = [[] for _ in range(ntri)]
    lower_pixels: list[tuple[int, int]] = []
    for x in range(W):
        for y in range(H):
            if mp[x, y][3] > 0:
                ti = triangle_at(x + 0.5, y + 0.5, tris, pts)
                tri_pixels[ti].append((x, y))
                lower_pixels.append((x, y))

    visible = [i for i in range(ntri) if tri_pixels[i]]
    visible_set = set(visible)
    min_mask_y = min(y for (_, y) in lower_pixels)
    max_mask_y = max(y for (_, y) in lower_pixels)

    # Adjacency only among visible crystal triangles.
    edge_to_tris: dict[tuple[int, int], list[int]] = {}
    for ti in visible:
        a, b, c = tris[ti]
        for (u, v) in ((a, b), (b, c), (c, a)):
            key = (u, v) if u < v else (v, u)
            edge_to_tris.setdefault(key, []).append(ti)
    neighbors: dict[int, set[int]] = {ti: set() for ti in visible}
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

    sources = [ti for ti in visible if min_y[ti] <= min_mask_y + 3]
    if not sources:
        sources = [ti for ti in visible if min_y[ti] <= min_mask_y + 5]

    # Source start times: smooth x stagger, not per-pixel random flash.
    start = {}
    for ti in sources:
        cx, cy = centroid[ti]
        start[ti] = 0.015 + 0.10 * value_noise(cx / 55.0, 2.3) \
            + 0.02 * ((cx / float(W)) - 0.5)

    arrival: dict[int, float] = {ti: 1e9 for ti in visible}
    heap: list[tuple[float, int]] = []
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
            down = max(0.0, ny - cy) / 4.0
            cost = 0.012 + 0.010 * dist / 8.0 + 0.018 * down
            cand = cur + cost
            if cand < arrival[nb]:
                arrival[nb] = cand
                heapq.heappush(heap, (cand, nb))

    # Fallback only if a visible component had no top source.
    finite = [arrival[ti] for ti in visible if arrival[ti] < 1e8]
    fallback = max(finite) + 0.10 if finite else 0.1
    for ti in visible:
        if arrival[ti] >= 1e8:
            arrival[ti] = fallback + (centroid[ti][1] - min_mask_y) / 20.0

    # Average face arrival onto shared vertices (weighted by covered pixels).
    incident: dict[int, list[tuple[float, int]]] = {}
    for ti in visible:
        w = len(tri_pixels[ti])
        for vi in tris[ti]:
            incident.setdefault(vi, []).append((arrival[ti], w))
    vert_arr = {}
    rvr = random.Random(SEED + 424242)
    for vi, vals in incident.items():
        total = sum(w for _, w in vals)
        val = sum(a * w for a, w in vals) / max(total, 1)
        # Tiny per-vertex variation gives each face a gentle internal slope
        # without per-pixel noise.
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
        base = (v - lo) / span * MAX_ARRIVAL
        # Keep the very top and early faces almost unchanged, but stretch the
        # mid/lower arrival so the lower crystal is still travelling around
        # 0.5 s. Monotonic, no flash.
        extra = max(0.0, base - 0.08)
        norm[p] = base + 0.6 * extra * (MAX_ARRIVAL - base) / MAX_ARRIVAL

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    op = out.load()
    for (x, y), v in norm.items():
        g = int(round(v * 255.0))
        op[x, y] = (g, g, g, 255)
    out.save(OUT)

    info = {
        "triangles": ntri,
        "visible_triangles": len(visible),
        "source_faces": len(sources),
        "lower_pixels": len(lower_pixels),
        "mask_y_min": min_mask_y,
        "mask_y_max": max_mask_y,
        "arrival_min_norm": min(norm.values()),
        "arrival_max_norm": max(norm.values()),
        "arrival_window_norm": ARRIVAL_WINDOW,
        "arrival_window_s": 0.16,
        "duration_s": 0.7,
        "median_arrival_norm": sorted(norm.values())[len(norm) // 2],
    }
    return out, info, mask


def main():
    out, info, mask = build()
    inactive_hash = hashlib.sha256(INACTIVE.read_bytes()).hexdigest()
    active_hash = hashlib.sha256(ACTIVE.read_bytes()).hexdigest()
    mask_hash = hashlib.sha256(MASK.read_bytes()).hexdigest()
    manifest = {
        "title": "L2 ConductiveRoof face-following activation arrival map",
        "created": "2026-11-18",
        "status": "runtime arrival map; approved colour/geometry untouched",
        "direction": "face-following, generally top to bottom; connected facet propagation, no long straight full-width front",
        "generator": "same SEED/point set/Delaunay rules as make_layered_core_approved_material.py",
        "source_seed": SEED,
        "window": "0.16 s soft arrival window on the 0.7 s CPU clock (0.22857 normalized)",
        "map": {
            "file": OUT.name,
            "role": "R=normalized arrival time; A=exposed lower mask; not a colour texture",
            "sha256": hashlib.sha256(OUT.read_bytes()).hexdigest(),
        },
        "info": info,
        "approved_sources": {
            "inactive": {"file": INACTIVE.name, "sha256": inactive_hash},
            "active": {"file": ACTIVE.name, "sha256": active_hash},
            "mask": {"file": MASK.name, "sha256": mask_hash},
        },
        "reference_note": "Built from this project's approved crystal triangles. The face-following propagation is the user's original request; Celeste evidence only supports internal light-level change, not a claim that the source game has this animation.",
        "regenerate": "D:/minic/envs/2024212971/python.exe make_layered_core_facetflow_arrival.py",
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(info, ensure_ascii=False))
    print("map", manifest["map"]["sha256"])
    print("sources", inactive_hash, active_hash, mask_hash)


if __name__ == "__main__":
    main()
