#!/usr/bin/env python3
"""Build the user-approved two-state L2 ConductiveRoof crystal (2026-11-18).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_layered_core_approved_material.py

Outputs (old crystal/black files and old previews stay untouched):
  layered_core_approved_inactive_256x32.png  proposed unlit: current dark-purple crystal
  layered_core_approved_active_256x32.png    proposed lit: approved internal-lit purple crystal
  layered_core_approved_mask_256x32.png      a=full lower crystal coverage; r/g facet response
  manifest_approved_20261118.json            hashes, coverage, facet and palette notes

Adopted via user confirmation of the v2 preview:
  - inactive is the old runtime dark-purple active image (NOT black);
  - active is the approved brightness_v2 internal-lit purple image;
  - same Delaunay facet layout, mask, upper stone shell and 256x32 geometry;
  - active 5-tone palette: deep #28143f, deep-mid #4a2470, mid #71369e,
    bright #b46bdd, rare highlight #d393ed.

The runtime shader sweeps from the exposed crystal's top to bottom over ~0.7 s using
this active texture; no external route/gold corners, no pulse and no TIME.
"""
from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
ROOF = PROJECT / "assets" / "level02_conductive_stone" / "conductive_roof_256x32.png"
BASE_OUT = HERE / "layered_core_approved_inactive_256x32.png"
ACTIVE_OUT = HERE / "layered_core_approved_active_256x32.png"
MASK_OUT = HERE / "layered_core_approved_mask_256x32.png"
MANIFEST = HERE / "manifest_approved_20261118.json"

W, H = 256, 32
SEED = 20261118

RUNS = [
    (5, 18), (8, 17), (12, 18), (6, 19), (7, 18), (11, 19), (4, 20),
    (9, 19), (13, 18), (5, 17), (10, 18), (9, 20), (6, 19), (12, 19),
    (7, 18), (8, 18), (5, 17), (11, 18), (9, 19), (6, 18), (13, 20),
    (8, 19), (4, 18), (10, 17), (7, 18), (9, 19), (6, 20), (12, 19),
    (8, 18), (5, 17), (11, 18), (7, 19), (13, 18), (6, 17), (4, 18),
]

# Inactive = the prior runtime dark-purple 5 tones. Active = user-approved v2
# internal-lit 5 tones. Deep/side faces dominate; pale faces are rare.
INACTIVE = [
    (22, 13, 34),
    (34, 20, 50),
    (52, 31, 76),
    (76, 47, 108),
    (104, 70, 146),  # rare pale face
]
ACTIVE = [
    (40, 20, 63),     # deep #28143f
    (74, 36, 112),    # deep-mid #4a2470
    (113, 54, 158),   # mid #71369e
    (180, 107, 221),  # bright #b46bdd
    (211, 147, 237),  # rare highlight #d393ed
]
SHADOW_INACTIVE = (12, 8, 18)
SHADOW_ACTIVE = (40, 20, 63)
LIGHT_DIR = (-0.65, -0.76)
SUPER = [(-1000.0, -1000.0), (3000.0, -1000.0), (-1000.0, 3000.0)]


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

    # Small shard points near existing vertices, for varied facet sizes.
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
    # Point list is coordinates; super triangle appended at fixed indices.
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


def tone_for(tri: tuple[int, int, int], pts: list[tuple[float, float]], idx: int) -> int:
    ax, ay = pts[tri[0]]
    bx, by = pts[tri[1]]
    cx, cy = pts[tri[2]]
    cx0 = (ax + bx + cx) / 3.0
    cy0 = (ay + by + cy) / 3.0
    edges = [((bx - ax), (by - ay)), ((cx - bx), (cy - by)), ((ax - cx), (ay - cy))]
    ex, ey = max(edges, key=lambda e: e[0] * e[0] + e[1] * e[1])
    nx, ny = -ey, ex
    ln = math.hypot(nx, ny)
    if ln > 1e-6:
        nx, ny = nx / ln, ny / ln
    if nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1] < 0.0:
        nx, ny = -nx, -ny
    lit = nx * LIGHT_DIR[0] + ny * LIGHT_DIR[1]
    h = random.Random(SEED + idx * 7919).random()
    if h < 0.38:
        tone = 0
    elif h < 0.64:
        tone = 1
    elif h < 0.88:
        tone = 2
    elif h < 0.97:
        tone = 3
    else:
        tone = 4
    top_bias = (20.0 - cy0) / 10.0 * 0.35
    if lit + top_bias > 0.15 and h < 0.55 and tone < 4:
        tone += 1
    if cy0 > 29.0 and h > 0.72 and tone > 0:
        tone -= 1
    return max(0, min(4, tone))


def build() -> tuple[Image.Image, Image.Image, Image.Image, dict]:
    src = Image.open(ROOF).convert("RGBA")
    assert src.size == (W, H), src.size
    boundary = boundary_values()
    rng = random.Random(SEED)
    pts = build_points(rng)
    tris = delaunay(pts)
    tones = [tone_for(t, pts, i) for i, t in enumerate(tris)]

    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    active = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bp, ap, mp, sp = base.load(), active.load(), mask.load(), src.load()

    for x in range(W):
        for y in range(boundary[x] + 1):
            bp[x, y] = sp[x, y]
            ap[x, y] = sp[x, y]

    def triangle_at(px: float, py: float) -> int:
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
        # Edge fallback: nearest triangle centroid.
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

    assigned = 0
    for x in range(W):
        for y in range(boundary[x] + 1, H):
            tone = tones[triangle_at(x + 0.5, y + 0.5)]
            if y == boundary[x] + 1:
                tone = 0
            if x == 0 or x == W - 1:
                tone = 0
            elif x == 1 or x == W - 2:
                tone = max(0, tone - 1)
            bp[x, y] = (*INACTIVE[tone], 255)
            ap[x, y] = (*ACTIVE[tone], 255)
            r = 255 if tone >= 3 else (170 if tone == 2 else (90 if tone == 1 else 0))
            g = 255 if tone == 4 else (150 if tone == 3 else 0)
            mp[x, y] = (r, g, 0, 255)
            assigned += 1

    for x in (22, 69, 117, 165, 212, 241):
        b = boundary[x]
        y = b + 1
        if y < H:
            bp[x, y] = (*INACTIVE[2], 255)
            ap[x, y] = (*ACTIVE[2], 255)
            mp[x, y] = (170, 90, 0, 255)

    tone_counts = {i: 0 for i in range(5)}
    for x in range(W):
        for y in range(boundary[x] + 1, H):
            v = bp[x, y][:3]
            for i, pal in enumerate(INACTIVE):
                if v == pal:
                    tone_counts[i] += 1
                    break

    info = {
        "facet_count": len(tris),
        "point_count": len(pts),
        "assigned_lower_pixels": assigned,
        "lower_min_px": H - 1 - max(boundary),
        "lower_max_px": H - 1 - min(boundary),
        "upper_shell_min_px": min(boundary) + 1,
        "upper_shell_max_px": max(boundary) + 1,
        "mask_pixels": sum(1 for y in range(H) for x in range(W) if mp[x, y][3] > 0),
        "mask_x0": sum(1 for y in range(H) if mp[0, y][3] > 0),
        "mask_x255": sum(1 for y in range(H) if mp[W - 1, y][3] > 0),
        "mask_row31": sum(1 for x in range(W) if mp[x, H - 1][3] > 0),
        "tone_counts": {str(k): v for k, v in tone_counts.items()},
        "boundary": boundary,
    }
    return base, active, mask, info


def validate(base: Image.Image, active: Image.Image, mask: Image.Image, info: dict) -> None:
    src = Image.open(ROOF).convert("RGBA")
    sp, bp, ap, mp = src.load(), base.load(), active.load(), mask.load()
    boundary = info["boundary"]
    assert base.size == active.size == mask.size == (W, H)
    assert info["facet_count"] >= 80, info
    assert info["mask_pixels"] > 2500, info
    assert info["mask_x0"] > 0 and info["mask_x255"] > 0, info
    assert info["mask_row31"] == W, info
    assert all(info["tone_counts"][str(i)] > 0 for i in range(4)), info
    for x in range(W):
        b = boundary[x]
        for y in range(b + 1):
            assert bp[x, y] == sp[x, y], ("upper shell changed", x, y)
            assert ap[x, y] == sp[x, y], ("active upper shell changed", x, y)
        for y in range(b + 1, H):
            assert mp[x, y][3] == 255, ("lower hole", x, y)
            assert bp[x, y] != sp[x, y], ("old lower pixel reused in base", x, y)
            assert ap[x, y] != sp[x, y], ("old lower pixel reused in active", x, y)
            assert bp[x, y] != ap[x, y], ("states identical", x, y)
    forbidden = {
        (76, 67, 73), (94, 82, 87), (135, 121, 118), (136, 122, 119),
        (134, 120, 117), (147, 133, 131), (131, 117, 115), (126, 112, 111),
        (171, 159, 150), (141, 126, 123), (98, 87, 91), (106, 95, 97),
        (111, 98, 100), (189, 177, 166), (185, 174, 162), (170, 158, 149),
        (166, 153, 145), (165, 152, 144), (162, 150, 142), (158, 145, 137),
    }
    for x in range(W):
        for y in range(boundary[x] + 1, H):
            assert bp[x, y][:3] not in forbidden, ("old stone tone in crystal", x, y)
            assert ap[x, y][:3] not in forbidden, ("old stone tone in active crystal", x, y)


base, active, mask, info = build()
validate(base, active, mask, info)
base.save(BASE_OUT)
active.save(ACTIVE_OUT)
mask.save(MASK_OUT)

manifest = {
    "title": "L2 ConductiveRoof approved two-state crystal + 0.7 s lit source",
    "created": "2026-11-18",
    "status": "user-approved static two-state; runtime adopted with a face-following top-to-bottom activation",
    "approved_from": "previews/layered_core_brightness_v2_20261118/ (user confirmed '采用这套两态')",
    "state_mapping": {
        "inactive": "current old runtime dark-purple active (not black)",
        "active": "approved v2 internal-lit purple (5-tone); face-following arrival map lights connected facets generally top to bottom over ~0.7 s",
    },
    "source_roof": {
        "file": "assets/level02_conductive_stone/conductive_roof_256x32.png",
        "sha256": hashlib.sha256(ROOF.read_bytes()).hexdigest(),
        "untouched": True,
    },
    "license": "Original pixel art authored in this project; source roof read only; no third-party pixels copied.",
    "reference_note": (
        "Celeste Core Block hot/cold continuous frames were checked for internal "
        "light-level change only. The face-following top-to-bottom activation is this "
        "project's user-authorized original timing, not a reference-game claim; "
        "no reference pixel, palette or mechanic is copied."
    ),
    "layers": {
        "inactive": {
            "file": BASE_OUT.name,
            "role": "proposed unlit: prior dark-purple crystal; not black",
            "sha256": hashlib.sha256(BASE_OUT.read_bytes()).hexdigest(),
        },
        "active": {
            "file": ACTIVE_OUT.name,
            "role": "user-approved internal-lit 5-tone purple crystal",
            "sha256": hashlib.sha256(ACTIVE_OUT.read_bytes()).hexdigest(),
        },
        "mask": {
            "file": MASK_OUT.name,
            "role": "a=full lower crystal coverage; r=facet response; g=pale-face response",
            "sha256": hashlib.sha256(MASK_OUT.read_bytes()).hexdigest(),
        },
    },
    "geometry": info,
    "palette": {
        "inactive": INACTIVE,
        "active": ACTIVE,
        "shadow_inactive": SHADOW_INACTIVE,
        "shadow_active": SHADOW_ACTIVE,
    },
    "design_notes": [
        "Inactive is the old dark-purple image; active is the approved v2 internal-lit image. Neither is black.",
        "Facet layout and upper shell are identical between both states and to the prior approved crystal.",
        "The shader uses this active texture only as the lit endpoint; the 0.7 s face-following activation is driven by a pausable CPU clock and no Shader.TIME.",
        "No external route, seam, moving head, corner node or 5x3 gold corner is part of this material.",
        "The force tint is still applied on top by the shader, preserving facet luminance.",
    ],
    "facetflow_activation": {
        "file": "layered_core_facetflow_arrival_256x32.png",
        "note": "face-following R arrival map; generated separately",
    },
    "linked_component": {
        "size": [200, 60],
        "files": ["layered_linked_base_200x60.png", "layered_linked_active_200x60.png",
                  "layered_linked_mask_200x60.png", "layered_linked_arrival_200x60.png"],
        "manifest": "manifest_linked_20261118.json",
    },
    "regenerate": "D:/minic/envs/2024212971/python.exe make_layered_core_approved_material.py",
}
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: info[k] for k in (
    "facet_count", "point_count", "assigned_lower_pixels", "lower_min_px",
    "lower_max_px", "upper_shell_min_px", "upper_shell_max_px", "mask_pixels",
    "mask_x0", "mask_x255", "mask_row31", "tone_counts",
)}, ensure_ascii=False))
print("inactive", hashlib.sha256(BASE_OUT.read_bytes()).hexdigest())
print("active", hashlib.sha256(ACTIVE_OUT.read_bytes()).hexdigest())
print("mask", hashlib.sha256(MASK_OUT.read_bytes()).hexdigest())
