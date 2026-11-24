#!/usr/bin/env python3
"""Build the first-platform facet id map (2026-11-19, face-tint sync).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_layered_core_first_facetids.py

Outputs (approved PNGs/mask/arrival untouched):
  layered_core_first_facetids_256x32.png
  manifest_first_facetids_20261119.json

The map reproduces the approved first-platform generator's own attribution:
same SEED, RUNS boundary, point set and Delaunay triangulation. Those functions
are copied here (not imported) so this script cannot re-run the approved
generator as a side effect. R = triangle index + 1 (0 = not crystal), A = the
approved mask's crystal coverage. No invalid ids.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
MASK = HERE / "layered_core_approved_mask_256x32.png"
OUT = HERE / "layered_core_first_facetids_256x32.png"
MANIFEST = HERE / "manifest_first_facetids_20261119.json"

W, H = 256, 32
SEED = 20261118
SUPER = [(-1000.0, -1000.0), (3000.0, -1000.0), (-1000.0, 3000.0)]

RUNS = [
    (5, 18), (8, 17), (12, 18), (6, 19), (7, 18), (11, 19), (4, 20),
    (9, 19), (13, 18), (5, 17), (10, 18), (9, 20), (6, 19), (12, 19),
    (7, 18), (8, 18), (5, 17), (11, 18), (9, 19), (6, 18), (13, 20),
    (8, 19), (4, 18), (10, 17), (7, 18), (9, 19), (6, 20), (12, 19),
    (8, 18), (5, 17), (11, 18), (7, 19), (13, 18), (6, 17), (4, 18),
]


def boundary_values() -> list[int]:
    vals: list[int] = []
    for length, value in RUNS:
        vals.extend([value] * length)
    if len(vals) < W:
        vals.extend([vals[-1]] * (W - len(vals)))
    return vals[:W]


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
            need = radius
            if (x - px) ** 2 + (y - py) ** 2 < need * need:
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


def main() -> None:
    mask = Image.open(MASK).convert("RGBA")
    assert mask.size == (W, H), mask.size
    rng = random.Random(SEED)
    pts = build_points(rng)
    tris = delaunay(pts)
    boundary = boundary_values()
    assert boundary == [v for v in boundary]

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ip = img.load()
    mp = mask.load()
    used: dict[int, int] = {}
    crystal = 0
    for y in range(H):
        for x in range(W):
            if mp[x, y][3] < 128:
                continue
            ti = triangle_at(x + 0.5, y + 0.5, tris, pts)
            assert 0 <= ti < len(tris), (x, y, ti)
            ip[x, y] = (ti + 1, 0, 0, 255)
            used[ti + 1] = used.get(ti + 1, 0) + 1
            crystal += 1

    assert crystal == sum(1 for y in range(H) for x in range(W) if mp[x, y][3] >= 128)
    for y in range(H):
        for x in range(W):
            a = ip[x, y][3]
            if mp[x, y][3] < 128:
                assert a == 0, (x, y)
            else:
                assert a == 255 and 1 <= ip[x, y][0] <= len(tris), (x, y)
    img.save(OUT)
    manifest = {
        "title": "L2 first-platform facet id map (face-tint sync)",
        "created": "2026-11-19",
        "status": "new asset; approved base/active/mask/arrival untouched",
        "provenance": {
            "generator": "make_layered_core_approved_material.py",
            "method": "same SEED/RUNS/points/Delaunay copied into this script (no import side effects)",
            "seed": SEED,
            "triangles": len(tris),
            "points": len(pts),
        },
        "files": {
            "facetid": {
                "file": OUT.name,
                "sha256": hashlib.sha256(OUT.read_bytes()).hexdigest(),
                "size": [W, H],
            },
            "mask": {
                "file": MASK.name,
                "sha256": hashlib.sha256(MASK.read_bytes()).hexdigest(),
            },
        },
        "pixels": crystal,
        "used_ids": len(used),
        "id_min": min(used),
        "id_max": max(used),
        "note": "R = triangle index + 1; 0 = not crystal. Same attribution as the approved generator; no new facet layout.",
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False))


if __name__ == "__main__":
    main()
