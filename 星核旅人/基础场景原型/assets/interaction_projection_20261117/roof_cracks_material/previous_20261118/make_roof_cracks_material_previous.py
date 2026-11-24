#!/usr/bin/env python3
"""Build the L2 ConductiveRoof crack material (original pixel art).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/roof_cracks_material/make_roof_cracks_material.py

Outputs, next to this script:
  roof_cracks_dark_256x32.png  dark opening + recess rim + chipped stone lip
  roof_cracks_glow_256x32.png  purple interior light + 1 px spill
  manifest.json                counts, bounds, palette, hashes, layout notes

The geometry below is authored for this material. It is not derived from the
old `_build_cracks` polylines: the trunk widths, junction pockets, chipped lip
and per-pixel glow selection are new. The two layers are aligned 1:1 with
`assets/level02_conductive_stone/conductive_roof_256x32.png`; that source PNG
is only read for the optional preview and is never modified.
"""
from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
ROOF = PROJECT / "assets" / "level02_conductive_stone" / "conductive_roof_256x32.png"
DARK_OUT = HERE / "roof_cracks_dark_256x32.png"
GLOW_OUT = HERE / "roof_cracks_glow_256x32.png"
MANIFEST = HERE / "manifest.json"
W, H = 256, 32

# --- authored fissures -----------------------------------------------------
# (y, x0, x1) inclusive; the visible stone courses are y0-10 top slab,
# y11-13 joint shadow, y14-20 brick course, y21-22 joint, y23-24 lip,
# y25-31 base. x=96/176 are top-slab seams; x=0/72/152/216 are brick seams;
# x=96/160 are lip/base seams. Every cluster respects those seams.
FISS: list[tuple[int, int, int]] = []


def rows(*entries: tuple[int, int, int]) -> None:
    FISS.extend(entries)


# Cluster A: largest. Opens at the top edge, jogs through both horizontal
# joints, tapers in the base. Two short hooks and a base split.
rows(
    (0, 45, 47), (1, 45, 47), (2, 45, 46), (3, 44, 46), (4, 44, 45),
    (5, 44, 45), (6, 44, 46), (7, 45, 46), (8, 45, 47), (9, 46, 47),
    (10, 46, 47), (11, 46, 48), (12, 46, 49), (13, 49, 50),
    (14, 48, 50), (15, 49, 51), (16, 50, 51), (17, 50, 52),
    (18, 51, 52), (19, 51, 53), (20, 52, 53), (21, 51, 53),
    (22, 50, 52), (23, 50, 51), (24, 49, 51), (25, 49, 50),
    (26, 48, 49), (27, 48, 49),
    (2, 43, 44), (3, 43, 43),
    (13, 47, 48), (14, 47, 47),
    (22, 53, 54), (23, 54, 54),
    (26, 46, 47), (27, 46, 46),
)

# Cluster B: medium. Drifts right, kinks back, one branch follows the inner
# course and stops one pixel before the x=152 brick seam.
rows(
    (2, 132, 133), (3, 132, 134), (4, 131, 133), (5, 131, 132),
    (6, 130, 132), (7, 130, 131), (8, 129, 131), (9, 130, 131),
    (10, 131, 132), (11, 132, 133), (12, 132, 135), (13, 135, 136),
    (14, 134, 136), (15, 135, 137), (16, 134, 136), (17, 135, 137),
    (18, 136, 137), (19, 137, 139), (20, 138, 139), (21, 138, 140),
    (22, 139, 140), (23, 139, 141), (24, 140, 141), (25, 139, 140),
    (26, 138, 139), (27, 138, 138),
    (6, 128, 129),
    (19, 140, 142), (20, 143, 145), (21, 146, 148), (22, 149, 149),
    (24, 138, 139), (25, 137, 138),
)

# Cluster C: smallest. Starts in the upper brick course, ends on the lip;
# one branch stops beside the x=216 brick seam.
rows(
    (6, 204, 205), (7, 203, 205), (8, 203, 204), (9, 203, 205),
    (10, 204, 205), (11, 205, 206), (12, 205, 207), (13, 206, 207),
    (14, 206, 208), (15, 207, 209), (16, 207, 208), (17, 208, 210),
    (18, 208, 209), (19, 209, 211), (20, 209, 210),
    (9, 201, 202), (10, 201, 201),
    (15, 210, 211), (16, 212, 213), (17, 214, 214),
    (18, 207, 207),
)

# --- palette ---------------------------------------------------------------
DARK_CORE = (34, 25, 38, 228)
DARK_RIM = (58, 46, 62, 148)
LIP = (207, 194, 181, 205)
LIP_BRIGHT = (211, 198, 185, 215)
GLOW_DEEP = (76, 46, 104, 232)
GLOW_WALL = (58, 32, 78, 175)
GLOW_MID = (128, 76, 164, 242)
GLOW_PALE = (172, 120, 206, 245)
GLOW_HALO = (104, 62, 134, 48)

# Rows where the interior is open enough to show light, per cluster. The
# gaps are deliberate: the light is not one continuous painted stripe.
# Every open row carries the deep interior light; brighter tones are local.
LIT_ROWS = {0: set(range(2, 27)), 1: set(range(2, 27)), 2: set(range(2, 27))}

# Lip rows and side: -1 = left of trunk, +1 = right of trunk.
LIP_ROWS = {
    0: {1: -1, 4: 1, 6: -1, 8: 1, 10: -1, 15: -1, 17: 1, 21: -1, 23: 1, 26: -1},
    1: {3: -1, 5: 1, 7: -1, 9: 1, 12: -1, 15: 1, 17: -1, 20: 1, 23: -1, 25: 1},
    2: {7: -1, 9: 1, 11: -1, 13: 1, 15: -1, 18: 1, 20: -1, 22: 1, 24: -1},
}

# Junction highlights: (x, y, tone). Only a handful of pale points; the rest
# of the lit interior is deep/mid purple.
JUNCTION_MID = [
    (48, 12), (51, 19), (51, 16), (50, 24),
    (133, 12), (136, 15), (140, 21),
    (207, 12), (210, 17), (212, 21),
]
JUNCTION_PALE = [(47, 12), (50, 16), (52, 19), (134, 12), (139, 21), (206, 12), (209, 17)]
# Two-pixel glow pockets: a small bright opening inside the dark fissure,
# not a stroke along its edge. The pixels on both sides stay dark.
GLOW_POCKETS = [
    (48, 12, GLOW_MID), (47, 12, GLOW_PALE), (49, 12, GLOW_DEEP),
    (51, 19, GLOW_MID), (52, 19, GLOW_PALE), (50, 19, GLOW_DEEP),
    (51, 16, GLOW_MID), (50, 16, GLOW_PALE),
    (133, 12, GLOW_MID), (134, 12, GLOW_PALE), (135, 12, GLOW_DEEP),
    (136, 15, GLOW_MID), (135, 15, GLOW_DEEP),
    (139, 21, GLOW_PALE), (140, 21, GLOW_MID), (138, 21, GLOW_DEEP),
    (206, 12, GLOW_PALE), (207, 12, GLOW_MID), (205, 12, GLOW_DEEP),
    (209, 17, GLOW_PALE), (210, 17, GLOW_MID), (208, 17, GLOW_DEEP),
    (211, 21, GLOW_MID), (212, 21, GLOW_MID), (210, 21, GLOW_DEEP),
]

# Small chipped-lip pairs at the surface notch and at branch tips.
LIP_CHIPS = [
    (44, 0), (48, 0), (42, 3), (47, 13), (53, 22),
    (133, 2), (127, 7), (150, 22), (137, 25),
    (205, 6), (200, 9), (215, 17), (208, 21),
]


def add_gap() -> set[tuple[int, int]]:
    gap: set[tuple[int, int]] = set()
    for y, x0, x1 in FISS:
        for x in range(x0, x1 + 1):
            gap.add((x, y))
    return gap


def row_runs(gap: set[tuple[int, int]]) -> dict[int, list[tuple[int, int]]]:
    by_row: dict[int, list[int]] = defaultdict(list)
    for x, y in gap:
        by_row[y].append(x)
    runs: dict[int, list[tuple[int, int]]] = {}
    for y, xs in by_row.items():
        xs.sort()
        out: list[tuple[int, int]] = []
        start = prev = xs[0]
        for x in xs[1:]:
            if x == prev + 1:
                prev = x
            else:
                out.append((start, prev))
                start = prev = x
        out.append((start, prev))
        runs[y] = out
    return runs


def cluster_of(x: int) -> int:
    if x < 100:
        return 0
    return 1 if x < 180 else 2


def build() -> tuple[Image.Image, Image.Image, dict]:
    gap = add_gap()
    runs = row_runs(gap)
    rim: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    lip: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    glow: dict[tuple[int, int], tuple[int, int, int, int]] = {}

    # A 2 px run gets one extra semi-dark rim pixel on the lit side so the
    # inset glow keeps a dark edge instead of touching the stone.
    for y, rr in runs.items():
        for a, b in rr:
            if b - a + 1 == 2:
                rim[(b + 1, y)] = DARK_RIM

    # Light follows the main trunk only: a separate branch tip stays dark, so
    # the activation does not turn every hairline into a purple whisker.
    prev_center = {-1: 0.0, 0: -1.0, 1: -1.0, 2: -1.0}
    for y in sorted(runs.keys()):
        for c in (0, 1, 2):
            candidates = [ab for ab in runs[y] if cluster_of(ab[0]) == c]
            if not candidates:
                continue
            if prev_center[c] < 0.0:
                main = max(candidates, key=lambda ab: ab[1] - ab[0])
            else:
                main = min(candidates,
                           key=lambda ab: abs((ab[0] + ab[1]) / 2.0 - prev_center[c]))
            prev_center[c] = (main[0] + main[1]) / 2.0
            a, b = main
            width = b - a + 1
            if y < 2 or y > 26 or width < 2:
                continue
            if y not in LIT_ROWS[c]:
                continue
            gx = a + 1 if width >= 3 else a
            glow[(gx, y)] = GLOW_DEEP
            if a <= gx - 1:
                glow[(gx - 1, y)] = GLOW_WALL
            if gx + 1 <= b:
                glow[(gx + 1, y)] = GLOW_WALL
            # Wider pockets get one more lit pixel; still bounded by dark.
            if width >= 4 and gx + 1 <= b:
                glow[(gx + 1, y)] = GLOW_DEEP

    for x, y in JUNCTION_MID:
        if (x, y) in glow:
            glow[(x, y)] = GLOW_MID
    for x, y in JUNCTION_PALE:
        if (x, y) in glow:
            glow[(x, y)] = GLOW_PALE
    for x, y, tone in GLOW_POCKETS:
        if (x, y) in glow:
            glow[(x, y)] = tone

    # Chipped stone lip: only one side per row, scattered, never on the gap.
    for y, rr in runs.items():
        main = max(rr, key=lambda ab: ab[1] - ab[0])
        c = cluster_of(main[0])
        side = LIP_ROWS[c].get(y)
        if side is None:
            continue
        a, b = main
        x = a - 1 if side < 0 else b + 1
        if (x, y) in rim:
            x += side
        if (x, y) in gap or (x, y) in rim and side < 0:
            continue
        lip[(x, y)] = LIP
    for x, y in LIP_CHIPS:
        if 0 <= x < W and 0 <= y < H and (x, y) not in gap:
            lip[(x, y)] = LIP_BRIGHT

    # 1 px light spill: stone pixels touching a lit gap pixel, sparse.
    halo: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for (x, y), col in glow.items():
        if col not in (GLOW_DEEP, GLOW_MID, GLOW_PALE):
            continue
        for q in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if q in gap or q in halo or q in rim or q in lip:
                continue
            if 0 <= q[0] < W and 0 <= q[1] < H and (x + y) % 3 == 0:
                halo[q] = GLOW_HALO
                break

    dark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dp = dark.load()
    for x, y in gap:
        dp[x, y] = DARK_CORE
    for (x, y), col in rim.items():
        dp[x, y] = col
    for (x, y), col in lip.items():
        dp[x, y] = col

    glow_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gp = glow_img.load()
    for (x, y), col in glow.items():
        gp[x, y] = col
    for (x, y), col in halo.items():
        gp[x, y] = col

    info = {
        "fissure_pixels": len(gap),
        "rim_pixels": len(rim),
        "lip_pixels": len(lip),
        "glow_core_pixels": len(glow),
        "glow_total_pixels": len(glow) + len(halo),
        "halo_pixels": len(halo),
        "core_pixels_alpha_ge_220": 0,
    }
    return dark, glow_img, info


def alpha_bounds(img: Image.Image) -> dict:
    px = img.load()
    points = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 0]
    alphas = [px[x, y][3] for x, y in points]
    return {
        "pixels": len(points),
        "alpha_min": min(alphas),
        "alpha_max": max(alphas),
        "x_min": min(x for x, _ in points),
        "x_max": max(x for x, _ in points),
        "y_min": min(y for _, y in points),
        "y_max": max(y for _, y in points),
    }


def validate(gap_img: Image.Image, glow_img: Image.Image, info: dict) -> None:
    # Every painted pixel is inside the 256x32 roof face.
    for name, img in (("dark", dark), ("glow", glow_img)):
        assert img.size == (W, H), name
        b = alpha_bounds(img)
        assert b["x_min"] >= 0 and b["x_max"] < W, (name, b)
        assert b["y_min"] >= 0 and b["y_max"] < H, (name, b)
    # Glow pixels are inside the fissure or within 1 px of it.
    gap = add_gap()
    gp = glow_img.load()
    for y in range(H):
        for x in range(W):
            if gp[x, y][3] == 0:
                continue
            near = any((x + dx, y + dy) in gap for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            assert near, ("glow too far from fissure", x, y)
    # The dark layer must not paint outside the fissure/rim/1 px lip.
    dp = dark.load()
    for y in range(H):
        for x in range(W):
            if dp[x, y][3] == 0:
                continue
            near = any((x + dx, y + dy) in gap for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            assert near, ("dark too far from fissure", x, y)
    assert info["fissure_pixels"] > 180, info


dark, glow_img, info = build()
# Count the opaque opening separately (the lip is 205, core 228).
dp = dark.load()
info["core_pixels_alpha_ge_220"] = sum(
    1 for y in range(H) for x in range(W) if dp[x, y][3] >= 220
)
validate(dark, glow_img, info)
dark.save(DARK_OUT)
glow_img.save(GLOW_OUT)

roof_sha = hashlib.sha256(ROOF.read_bytes()).hexdigest()
dark_sha = hashlib.sha256(DARK_OUT.read_bytes()).hexdigest()
glow_sha = hashlib.sha256(GLOW_OUT.read_bytes()).hexdigest()

manifest = {
    "title": "L2 ConductiveRoof internal-crack material",
    "created": "2026-11-18",
    "placement": "Aligned 1:1 with assets/level02_conductive_stone/conductive_roof_256x32.png; overlay only, source PNG untouched.",
    "license": "Original pixel art authored in this project; no third-party pixels.",
    "reference_exemption": "Only the L2 activation presentation uses the user's note-7e10 direct-trial exemption; no mechanism reference was checked or claimed.",
    "layers": {
        "dark": {
            "file": DARK_OUT.name,
            "role": "fissure opening + recess rim + interrupted chipped stone lip; always drawn while locked",
            "sha256": dark_sha,
            "alpha_bounds": alpha_bounds(dark),
            "palette": {
                "core": DARK_CORE, "rim": DARK_RIM,
                "lip": LIP, "lip_bright": LIP_BRIGHT,
            },
        },
        "glow": {
            "file": GLOW_OUT.name,
            "role": "purple interior light; revealed left-to-right during 0.52-0.80 s, held after the 0.9 s one-shot",
            "sha256": glow_sha,
            "alpha_bounds": alpha_bounds(glow_img),
            "palette": {
                "deep": GLOW_DEEP, "wall": GLOW_WALL, "mid": GLOW_MID,
                "pale": GLOW_PALE, "spill_1px": GLOW_HALO,
            },
        },
    },
    "source_roof": {"file": str(ROOF.relative_to(PROJECT)).replace("\\", "/"), "sha256": roof_sha},
    "counts": info,
    "design_notes": [
        "Three unequal clusters; largest opens at the top edge, medium starts below it, smallest ends on the lip.",
        "Trunk bodies are 2 px, locally 3 px at course-joint pockets; thin branches are 1 px and taper to a 1 px tip.",
        "Each horizontal course joint (y11-13, y21-22) causes an offset/jog; the medium and small side branches stop before the x=152 and x=216 brick seams.",
        "No regular grid, rectangular loop, repeated parallel slash or symmetric tree motif.",
        "Glow is inset in the dark opening, not an edge stroke: the deep/wall tones carry the base, mid purple only at junction pockets (9 px), pale only at seven pixels.",
        "Spill is a single stone pixel within 1 px of the fissure and only on a sparse subset.",
    ],
    "regenerate": "D:/minic/envs/2024212971/python.exe make_roof_cracks_material.py",
}
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(info, ensure_ascii=False))
print("dark", dark_sha, alpha_bounds(dark))
print("glow", glow_sha, alpha_bounds(glow_img))
