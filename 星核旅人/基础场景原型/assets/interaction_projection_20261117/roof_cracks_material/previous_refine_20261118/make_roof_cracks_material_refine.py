#!/usr/bin/env python3
"""Build the refined L2 ConductiveRoof crack material (original pixel art).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/roof_cracks_material/make_roof_cracks_material.py

Outputs, next to this script:
  roof_cracks_dark_256x32.png  dark opening + recess shadow + chipped stone lip
  roof_cracks_glow_256x32.png  purple interior light + 1 px spill
  manifest.json                counts, bounds, palette, hashes, layout notes

The previous first material is kept in `previous_20261118/` and marked
superseded. This geometry is authored for this material (three mains, three
attached branches, four short secondary cracks); it is not a raster of the old
`_build_cracks` polylines. The source roof PNG is only hashed, never modified.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
ROOF = PROJECT / "assets" / "level02_conductive_stone" / "conductive_roof_256x32.png"
DARK_OUT = HERE / "roof_cracks_dark_256x32.png"
GLOW_OUT = HERE / "roof_cracks_glow_256x32.png"
MANIFEST = HERE / "manifest.json"
W, H = 256, 32
TOP_LIMIT, BOTTOM_LIMIT = 2, 29  # keep >=2 px from the roof outline

# --- authored geometry -----------------------------------------------------
# Three mains. All material stays inside y=2..29. A is an S, B is a skew with
# a short horizontal run along the y=12 joint, C is small with a short
# horizontal jog at y=13 and ends just before the x=216 brick seam.
MAINS = [
    {"id": "A", "rows": [
        (2, 49, 49), (3, 48, 49), (4, 47, 48), (5, 47, 48), (6, 46, 47),
        (7, 46, 47), (8, 45, 46), (9, 45, 46), (10, 45, 46), (11, 46, 46),
        (12, 46, 47), (13, 47, 48), (14, 48, 49), (15, 49, 50), (16, 49, 50),
        (17, 50, 51), (18, 51, 52), (19, 51, 52), (20, 52, 53), (21, 52, 53),
        (22, 51, 51), (23, 51, 52), (24, 50, 51), (25, 50, 51), (26, 49, 50),
        (27, 49, 49), (28, 48, 48),
    ], "bright": {6, 7, 8, 9, 13, 14, 15, 16, 20, 21, 22},
       "lip_rows": {4: -1, 8: -1, 12: -1, 16: -1, 20: -1, 24: -1}},
    {"id": "B", "rows": [
        (3, 128, 128), (4, 128, 129), (5, 129, 130), (6, 129, 130),
        (7, 130, 131), (8, 131, 132), (9, 131, 132), (10, 132, 133),
        (11, 133, 134), (12, 134, 137), (13, 137, 137), (14, 136, 137),
        (15, 135, 136), (16, 135, 136), (17, 135, 136), (18, 136, 137),
        (19, 137, 138), (20, 138, 139), (21, 139, 140), (22, 139, 139),
        (23, 140, 141), (24, 140, 141), (25, 139, 140), (26, 138, 139),
        (27, 138, 138),
    ], "bright": {6, 7, 8, 12, 13, 14, 18, 19},
       "lip_rows": {5: -1, 9: -1, 13: -1, 17: -1, 21: -1, 25: -1}},
    {"id": "C", "rows": [
        (7, 211, 211), (8, 210, 211), (9, 210, 211), (10, 209, 210),
        (11, 209, 210), (12, 208, 208), (13, 207, 209), (14, 209, 210),
        (15, 210, 211), (16, 211, 212), (17, 212, 213), (18, 212, 212),
        (19, 213, 214), (20, 213, 214), (21, 214, 214),
    ], "bright": {9, 10, 13, 14, 15, 18},
       "lip_rows": {8: -1, 11: -1, 15: -1, 19: -1}},
]

# Three attached 1 px branches at the main junctions.
BRANCHES = [
    {"id": "A1", "rows": [(8, 44, 44), (7, 43, 43), (6, 43, 43), (5, 42, 42)],
     "lip": (42, 4)},
    {"id": "A2", "rows": [(19, 53, 53), (18, 54, 54), (17, 55, 55), (16, 55, 55)],
     "lip": (56, 15)},
    {"id": "C1", "rows": [(10, 208, 208), (9, 207, 207), (8, 206, 206)],
     "lip": (205, 7)},
]

# Four short secondary cracks, each inside a different stone block:
# S4 top slab (0..96), S1 top slab (96..176), S2 brick band (152..216),
# S3 base band (96..160). They are not connected to a main and do not cross
# the block seams. Lengths 5..6 px, different angles.
SECONDARIES = [
    {"id": "S1", "rows": [(4, 150, 150), (5, 151, 151), (6, 151, 151), (7, 152, 152),
                          (8, 153, 153), (9, 154, 154)], "lip": (149, 4)},
    {"id": "S2", "rows": [(15, 183, 183), (16, 182, 182), (17, 182, 182),
                          (18, 181, 181), (19, 180, 180)], "lip": (184, 15)},
    {"id": "S3", "rows": [(28, 118, 118), (27, 119, 119), (26, 120, 120),
                          (25, 121, 121), (24, 122, 122), (24, 123, 123)],
     "lip": (117, 28)},
    {"id": "S4", "rows": [(10, 76, 76), (9, 77, 77), (8, 77, 77), (7, 78, 78),
                          (6, 78, 78)], "lip": (75, 10)},
]

# --- palette ---------------------------------------------------------------
DARK_CORE = (34, 25, 38, 228)
DARK_RIM = (58, 46, 62, 148)
LIP = (203, 190, 177, 200)
LIP_BRIGHT = (209, 196, 183, 215)
GLOW_DEEP = (110, 63, 168, 232)   # deep saturated violet base
GLOW_WALL = (80, 44, 120, 190)    # weak branch/base tone, one step down
GLOW_MID = (167, 93, 229, 242)    # ~#a75de5
GLOW_MID2 = (185, 122, 237, 244)  # ~#b97aed
GLOW_PALE = (205, 158, 245, 246)  # a handful of pale points
GLOW_HALO = (140, 82, 190, 55)    # 1 px spill only


def add_gap() -> dict[tuple[int, int], tuple[str, str]]:
    gap: dict[tuple[int, int], tuple[str, str]] = {}
    for main in MAINS:
        for y, x0, x1 in main["rows"]:
            for x in range(x0, x1 + 1):
                gap[(x, y)] = ("main", main["id"])
    for branch in BRANCHES:
        for y, x0, x1 in branch["rows"]:
            for x in range(x0, x1 + 1):
                gap.setdefault((x, y), ("branch", branch["id"]))
    for secondary in SECONDARIES:
        for y, x0, x1 in secondary["rows"]:
            for x in range(x0, x1 + 1):
                gap.setdefault((x, y), ("secondary", secondary["id"]))
    return gap


def run_of(crack: dict, y: int) -> tuple[int, int] | None:
    for yy, x0, x1 in crack["rows"]:
        if yy == y:
            return x0, x1
    return None


def build() -> tuple[Image.Image, Image.Image, dict]:
    gap = add_gap()

    # Stone lip first (interrupted, light/upper side), then the shadow rim.
    lip: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for main in MAINS:
        for y, side in main["lip_rows"].items():
            run = run_of(main, y)
            if run is None:
                continue
            x = run[0] - 1 if side < 0 else run[1] + 1
            if (x, y) not in gap and TOP_LIMIT <= y <= BOTTOM_LIMIT:
                lip[(x, y)] = LIP
    for branch in BRANCHES:
        x, y = branch["lip"]
        if (x, y) not in gap and TOP_LIMIT <= y <= BOTTOM_LIMIT:
            lip[(x, y)] = LIP_BRIGHT
    for secondary in SECONDARIES:
        x, y = secondary["lip"]
        if (x, y) not in gap and TOP_LIMIT <= y <= BOTTOM_LIMIT:
            lip[(x, y)] = LIP

    rim: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for main in MAINS:
        for y, x0, x1 in main["rows"]:
            # One continuous shadow pixel on the lower/right edge. No second
            # shadow on the light side: that thickened the crack back into a
            # black scar in the first version.
            rx, ry = x1 + 1, y
            if (rx, ry) not in gap and (rx, ry) not in lip \
                    and TOP_LIMIT <= ry <= BOTTOM_LIMIT:
                rim[(rx, ry)] = DARK_RIM
    # Short shadows under the fine cracks keep them readable at 1x without
    # turning them into mains: one 1 px shadow on part of each fine line.
    for branch in BRANCHES:
        y, x0, x1 = branch["rows"][-1]
        for q in ((x1 + 1, y), (x0 - 1, y)):
            if q not in gap and q not in lip and TOP_LIMIT <= q[1] <= BOTTOM_LIMIT:
                rim[q] = DARK_RIM
                break
    for secondary in SECONDARIES:
        for y, x0, x1 in secondary["rows"][1:-1:2]:
            q = (x1 + 1, y)
            if q not in gap and q not in lip and TOP_LIMIT <= q[1] <= BOTTOM_LIMIT:
                rim[q] = DARK_RIM
    # Shadow under the two short horizontal runs.
    for p in ((135, 13), (208, 14)):
        if p not in gap and p not in lip and TOP_LIMIT <= p[1] <= BOTTOM_LIMIT:
            rim[p] = DARK_RIM

    glow: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for main in MAINS:
        for y, x0, x1 in main["rows"]:
            width = x1 - x0 + 1
            bright = y in main["bright"]
            if width == 1:
                glow[(x0, y)] = GLOW_MID if bright else GLOW_DEEP
                continue
            if bright:
                if width == 2:
                    glow[(x0, y)] = GLOW_MID if y % 4 != 0 else GLOW_MID2
                    glow[(x1, y)] = GLOW_WALL
                else:
                    # Short horizontal run: two bright centre pixels, dark ends.
                    glow[(x0, y)] = GLOW_MID
                    glow[(x0 + 1, y)] = GLOW_MID2
                    for x in range(x0 + 2, x1 + 1):
                        glow[(x, y)] = GLOW_WALL
            else:
                if width == 2:
                    glow[(x0, y)] = GLOW_DEEP
                    glow[(x1, y)] = GLOW_WALL
                else:
                    for x in range(x0, x1 + 1):
                        glow[(x, y)] = GLOW_WALL
    for branch in BRANCHES:
        for i, (y, x0, x1) in enumerate(branch["rows"]):
            glow[(x0, y)] = GLOW_DEEP if i == 0 else GLOW_WALL
    for secondary in SECONDARIES:
        for i, (y, x0, x1) in enumerate(secondary["rows"]):
            if i == len(secondary["rows"]) // 2:
                glow[(x0, y)] = GLOW_WALL

    # Very few pale points, all inside bright main pockets.
    for p in [(47, 13), (52, 20), (135, 12), (136, 18), (208, 13), (212, 17)]:
        if p in glow:
            glow[p] = GLOW_PALE

    halo: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for (x, y), color in glow.items():
        if color not in (GLOW_MID, GLOW_MID2, GLOW_PALE):
            continue
        for q in ((x - 1, y), (x, y - 1)):
            if q in gap or q in lip or q in rim or q in halo:
                continue
            if TOP_LIMIT <= q[1] <= BOTTOM_LIMIT:
                halo[q] = GLOW_HALO
                break

    dark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dp = dark.load()
    for (x, y) in gap:
        dp[x, y] = DARK_CORE
    for (x, y), color in rim.items():
        dp[x, y] = color
    for (x, y), color in lip.items():
        dp[x, y] = color

    glow_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gp = glow_img.load()
    for (x, y), color in glow.items():
        gp[x, y] = color
    for (x, y), color in halo.items():
        gp[x, y] = color

    info = {
        "mains": len(MAINS),
        "attached_branches": len(BRANCHES),
        "secondary_cracks": len(SECONDARIES),
        "fissure_pixels": len(gap),
        "rim_pixels": len(rim),
        "lip_pixels": len(lip),
        "glow_core_pixels": len(glow),
        "glow_total_pixels": len(glow) + len(halo),
        "mid_glow_pixels": sum(1 for c in glow.values() if c in (GLOW_MID, GLOW_MID2)),
        "pale_glow_pixels": sum(1 for c in glow.values() if c == GLOW_PALE),
        "halo_pixels": len(halo),
    }
    return dark, glow_img, info


def alpha_bounds(img: Image.Image) -> dict:
    px = img.load()
    points = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 0]
    alphas = [px[x, y][3] for x, y in points]
    return {
        "pixels": len(points), "alpha_min": min(alphas), "alpha_max": max(alphas),
        "x_min": min(x for x, _ in points), "x_max": max(x for x, _ in points),
        "y_min": min(y for _, y in points), "y_max": max(y for _, y in points),
    }


def validate(dark: Image.Image, glow: Image.Image, info: dict) -> None:
    gap = add_gap()
    for name, img in (("dark", dark), ("glow", glow)):
        assert img.size == (W, H), name
        bounds = alpha_bounds(img)
        assert TOP_LIMIT <= bounds["y_min"] and bounds["y_max"] <= BOTTOM_LIMIT, (name, bounds)
        assert 0 <= bounds["x_min"] and bounds["x_max"] < W, (name, bounds)
        px = img.load()
        for y in range(H):
            for x in range(W):
                if px[x, y][3] == 0:
                    continue
                near = any((x + dx, y + dy) in gap
                           for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                assert near, (name, "pixel too far from a fissure", x, y)
    assert info["fissure_pixels"] >= 140, info
    assert 18 <= info["mid_glow_pixels"] <= 34, info
    assert 4 <= info["pale_glow_pixels"] <= 8, info
    assert 6 <= info["attached_branches"] + info["secondary_cracks"] <= 8, info


dark, glow, info = build()
validate(dark, glow, info)
dark.save(DARK_OUT)
glow.save(GLOW_OUT)

roof_sha = hashlib.sha256(ROOF.read_bytes()).hexdigest()
manifest = {
    "title": "L2 ConductiveRoof refined internal-crack material",
    "created": "2026-11-18",
    "status": "refined after coordinator review of the first material (kept in previous_20261118/ as superseded)",
    "placement": "Aligned 1:1 with assets/level02_conductive_stone/conductive_roof_256x32.png; overlay only, source PNG untouched.",
    "license": "Original pixel art authored in this project; no third-party pixels.",
    "reference_exemption": "Only this L2 activation presentation uses the user's note-7e10 direct-trial exemption; no mechanism reference was checked or claimed.",
    "layers": {
        "dark": {
            "file": DARK_OUT.name,
            "role": "2 px main opening (1 px at pins/tips) + 1 px shadow edge + interrupted chipped stone lip; always drawn while locked",
            "sha256": hashlib.sha256(DARK_OUT.read_bytes()).hexdigest(),
            "alpha_bounds": alpha_bounds(dark),
            "palette": {"core": DARK_CORE, "rim": DARK_RIM, "lip": LIP, "lip_bright": LIP_BRIGHT},
        },
        "glow": {
            "file": GLOW_OUT.name,
            "role": "purple interior light, revealed left-to-right during 0.52-0.80 s; deep base, mid-bright main segments, weak branches, 1 px spill",
            "sha256": hashlib.sha256(GLOW_OUT.read_bytes()).hexdigest(),
            "alpha_bounds": alpha_bounds(glow),
            "palette": {"deep": GLOW_DEEP, "wall": GLOW_WALL, "mid": GLOW_MID,
                        "mid2": GLOW_MID2, "pale": GLOW_PALE, "spill_1px": GLOW_HALO},
        },
    },
    "source_roof": {"file": str(ROOF.relative_to(PROJECT)).replace("\\", "/"), "sha256": roof_sha},
    "counts": info,
    "design_notes": [
        "Three mains: A is an S, B is a skew with a 4 px horizontal run at y12, C is short with a 3 px jog at y13 and stops before the x216 seam.",
        "Three attached 1 px branches (A1, A2, C1) and four short secondary cracks in different stone blocks (top-left, top-right, brick band, base).",
        "Main bodies are 2 px with 1 px pins/tips; the 3 px junction pockets are formed where a branch meets the main. All material is inside y2..29 (>=2 px from the roof top/bottom outline).",
        "No regular grid, rectangle loop, repeated parallel slash or symmetric tree motif; secondaries are 5-6 px, unequal and non-parallel.",
        "Main glow uses mid-bright #a75de5/#b97aed on about a third of the effective length, deep violet elsewhere; branches use the weaker wall tone.",
        "Spill is one stone pixel within 1 px of the fissure and only around bright main pixels.",
    ],
    "regenerate": "D:/minic/envs/2024212971/python.exe make_roof_cracks_material.py",
}
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(info, ensure_ascii=False))
print("dark", alpha_bounds(dark), hashlib.sha256(DARK_OUT.read_bytes()).hexdigest())
print("glow", alpha_bounds(glow), hashlib.sha256(GLOW_OUT.read_bytes()).hexdigest())
