#!/usr/bin/env python3
"""Build the L2 ConductiveRoof ore-material revision (2026-11-18).

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_layered_core_ore_material.py

Outputs, next to this script (old base/mask are not overwritten):
  layered_core_ore_base_256x32.png    inactive: faint grey-black ore faces
  layered_core_ore_active_256x32.png  activated: dark-purple ore faces
  layered_core_ore_mask_256x32.png    a = exposed lower layer (to x0/x255 and row 31)
                                      r = crystal-body response, g = highlight response
  manifest_ore_20261118.json          hashes, coverage, palette, cluster list

Design:
  - The upper stone shell keeps the original roof rows and the same irregular
    junction (18..21 px). Everything below it, all the way to the last row and
    both outer columns, is new ore material; no old stone frame, lip, side wall
    or original gold corner is reused.
  - Lower material is a continuous dark mother rock with embedded small
    faceted crystal clusters (varied 2..5 px shapes, uneven spacing, a few
    grouped). Three/four limited ore tones give deep faces, mid faces and rare
    highlights. It is deliberately not a smooth gradient, not a regular
    Voronoi/line net, not repeated diamonds and not per-pixel noise.
  - The original 256x32 beam, top stone rows, outer silhouette, collision and
    placement are unchanged. The original roof PNG is read only.
"""
from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
ROOF = PROJECT / "assets" / "level02_conductive_stone" / "conductive_roof_256x32.png"
BASE_OUT = HERE / "layered_core_ore_base_256x32.png"
ACTIVE_OUT = HERE / "layered_core_ore_active_256x32.png"
MASK_OUT = HERE / "layered_core_ore_mask_256x32.png"
MANIFEST = HERE / "manifest_ore_20261118.json"

W, H = 256, 32
SEED = 20261118

# Same hand-run junction as the first draft: shell thickness 18..21 px and
# lower material 11..14 px. The interface itself is not being redesigned.
RUNS = [
    (5, 18), (8, 17), (12, 18), (6, 19), (7, 18), (11, 19), (4, 20),
    (9, 19), (13, 18), (5, 17), (10, 18), (9, 20), (6, 19), (12, 19),
    (7, 18), (8, 18), (5, 17), (11, 18), (9, 19), (6, 18), (13, 20),
    (8, 19), (4, 18), (10, 17), (7, 18), (9, 19), (6, 20), (12, 19),
    (8, 18), (5, 17), (11, 18), (7, 19), (13, 18), (6, 17), (4, 18),
]

# Inactive: faint grey-black mineral faces, not a flat black bar.
INACTIVE_MOTHER = [(7, 7, 9), (11, 11, 14), (16, 15, 19)]
INACTIVE_CRYSTAL = [
    (17, 14, 23),     # deep edge
    (29, 25, 38),     # mid face
    (48, 42, 60),     # light face
    (72, 65, 86),     # rare highlight
]
# Activated: dark purple mother with readable purple facets.
ACTIVE_MOTHER = [(16, 11, 23), (23, 16, 33), (33, 24, 47)]
ACTIVE_CRYSTAL = [
    (42, 26, 62),
    (67, 43, 94),
    (96, 64, 132),
    (128, 90, 172),
]
SHADOW_INACTIVE = (4, 4, 6)
SHADOW_ACTIVE = (12, 8, 18)

# Hand-shaped small crystal blobs (dx, dy). 2..5 px wide, 2..4 px tall.
# Different silhouettes; some are mirrored at placement so no one diamond tile
# repeats across the beam.
SHAPES = [
    [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (1, 2)],
    [(0, 0), (1, 0), (1, 1), (2, 1), (1, 2)],
    [(0, 0), (1, 1), (0, 1), (1, 2), (2, 2)],
    [(0, 0), (1, 0), (2, 1), (1, 1), (2, 2), (3, 2)],
    [(0, 0), (1, 0), (0, 1), (1, 1), (2, 2)],
    [(0, 0), (1, 1), (2, 1), (1, 2), (2, 2), (3, 3)],
    [(0, 0), (0, 1), (1, 1), (0, 2), (1, 2)],
    [(0, 0), (1, 0), (2, 0), (1, 1), (2, 1), (3, 2)],
    [(0, 0), (1, 1), (0, 1), (1, 2)],
    [(0, 0), (1, 0), (0, 1), (1, 1), (2, 1), (2, 2)],
    [(0, 1), (1, 0), (1, 1), (2, 1), (1, 2)],
    [(0, 0), (1, 0), (1, 1), (2, 1), (2, 2), (1, 3)],
]

# Broad hand-placed mother-rock plates for quiet block variation behind ore.
PLATES = [
    (14, 25, 8, 2, 1), (29, 22, 5, 3, 2), (48, 27, 7, 2, 1),
    (67, 22, 6, 2, 2), (88, 26, 9, 2, 1), (111, 23, 5, 3, 1),
    (132, 28, 8, 2, 2), (156, 22, 7, 2, 1), (176, 26, 5, 3, 1),
    (198, 24, 9, 2, 2), (222, 28, 6, 2, 1), (239, 22, 5, 3, 1),
]


def boundary_values() -> list[int]:
    vals: list[int] = []
    for length, value in RUNS:
        vals.extend([value] * length)
    if len(vals) < W:
        vals.extend([vals[-1]] * (W - len(vals)))
    return vals[:W]


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


def cluster_list(rng: random.Random) -> list[dict]:
    clusters: list[dict] = []
    x = 7
    pair_credit = 0
    while x < W - 7:
        gap = rng.randint(4, 12)
        if pair_credit > 0:
            gap = rng.randint(2, 5)
            pair_credit -= 1
        x += gap
        if x >= W - 7:
            break
        shape = SHAPES[rng.randrange(len(SHAPES))]
        if rng.random() < 0.45:
            shape = [(-dx, dy) for (dx, dy) in shape]
            min_dx = min(dx for dx, _ in shape)
            shape = [(dx - min_dx, dy) for (dx, dy) in shape]
        w = max(dx for dx, _ in shape) + 1
        h = max(dy for _, dy in shape) + 1
        top = rng.randint(21, H - 1 - h)
        if rng.random() < 0.30:
            pair_credit = rng.randint(1, 2)
        clusters.append({"x": x, "y": top, "w": w, "h": h, "shape": shape})
    return clusters


def build() -> tuple[Image.Image, Image.Image, Image.Image, dict]:
    src = Image.open(ROOF).convert("RGBA")
    assert src.size == (W, H), src.size
    boundary = boundary_values()
    rng = random.Random(SEED)
    clusters = cluster_list(rng)

    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    active = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bp, ap, mp, sp = base.load(), active.load(), mask.load(), src.load()

    # Upper shell verbatim in both states.
    for x in range(W):
        for y in range(boundary[x] + 1):
            bp[x, y] = sp[x, y]
            ap[x, y] = sp[x, y]

    # Mother rock first: low-frequency blocks, not per-pixel noise.
    for x in range(W):
        b = boundary[x]
        for y in range(b + 1, H):
            n = value_noise(x / 8.5, y / 4.2)
            level = 0 if n < 0.38 else (1 if n < 0.74 else 2)
            if y == b + 1:
                bp[x, y] = (*SHADOW_INACTIVE, 255)
                ap[x, y] = (*SHADOW_ACTIVE, 255)
                mp[x, y] = (0, 0, 0, 255)
                continue
            # New dark side faces at the outer columns; still mineral, not stone.
            if x < 2 or x >= W - 2:
                level = 0
            bp[x, y] = (*INACTIVE_MOTHER[level], 255)
            ap[x, y] = (*ACTIVE_MOTHER[level], 255)
            mp[x, y] = (0, 0, 0, 255)

    # Broad plates quiet second tone on mother rock.
    for (px, py, pw, ph, level) in PLATES:
        for x in range(px, min(W, px + pw)):
            b = boundary[x]
            for y in range(py, min(H, py + ph)):
                if y <= b:
                    continue
                if bp[x, y][3] == 0:
                    continue
                if y == b + 1:
                    continue
                bp[x, y] = (*INACTIVE_MOTHER[level], 255)
                ap[x, y] = (*ACTIVE_MOTHER[level], 255)

    crystal_count = 0
    highlight_count = 0
    # Place crystals, clipped by the real junction and outer side faces.
    for ci, c in enumerate(clusters):
        for (dx, dy) in c["shape"]:
            x = c["x"] + dx
            y = c["y"] + dy
            if x < 0 or x >= W or y <= boundary[x] or y >= H:
                continue
            # Outer two columns are a new dark mineral side plane; keep the
            # cluster but dim it there.
            side = x < 2 or x >= W - 2
            # Facet tone from position in the blob: top-left lit, lower-right deep.
            if dy == 0 and dx <= 1:
                tone = 3 if (dx == 0 and ci % 3 == 0 and not side) else 2
            elif dy == c["h"] - 1 or dx == c["w"] - 1:
                tone = 1
            else:
                tone = 2
            if side:
                tone = max(0, tone - 1)
            bp[x, y] = (*INACTIVE_CRYSTAL[tone], 255)
            ap[x, y] = (*ACTIVE_CRYSTAL[tone], 255)
            crystal = 255 if tone >= 2 else 150
            highlight = 255 if tone == 3 else (170 if tone == 2 else 0)
            mp[x, y] = (crystal, highlight, 0, 255)
            crystal_count += 1
            if tone == 3:
                highlight_count += 1

    # A few tiny glints in the top shadow row and last row keep the edges from
    # reading as a solid black frame, while still new ore material.
    for x in (24, 71, 118, 166, 214, 243):
        b = boundary[x]
        y = b + 1
        if y < H:
            bp[x, y] = (*INACTIVE_CRYSTAL[2], 255)
            ap[x, y] = (*ACTIVE_CRYSTAL[2], 255)
            mp[x, y] = (180, 90, 0, 255)

    info = {
        "clusters": len(clusters),
        "crystal_pixels": crystal_count,
        "highlight_pixels": highlight_count,
        "lower_min_px": H - 1 - max(boundary),
        "lower_max_px": H - 1 - min(boundary),
        "upper_shell_min_px": min(boundary) + 1,
        "upper_shell_max_px": max(boundary) + 1,
        "mask_pixels": sum(1 for y in range(H) for x in range(W) if mp[x, y][3] > 0),
        "left_edge_mask": sum(1 for y in range(H) if mp[0, y][3] > 0),
        "right_edge_mask": sum(1 for y in range(H) if mp[W - 1, y][3] > 0),
        "bottom_row_mask": sum(1 for x in range(W) if mp[x, H - 1][3] > 0),
        "cluster_boxes": [[c["x"], c["y"], c["w"], c["h"]] for c in clusters],
        "boundary": boundary,
    }
    return base, active, mask, info


def validate(base: Image.Image, active: Image.Image, mask: Image.Image, info: dict) -> None:
    src = Image.open(ROOF).convert("RGBA")
    sp, bp, ap, mp = src.load(), base.load(), active.load(), mask.load()
    boundary = info["boundary"]
    assert base.size == active.size == mask.size == (W, H)
    assert info["mask_pixels"] > 2500, info
    assert info["left_edge_mask"] > 0 and info["right_edge_mask"] > 0, info
    assert info["bottom_row_mask"] == W, info
    for x in range(W):
        b = boundary[x]
        for y in range(b + 1):
            assert bp[x, y] == sp[x, y], ("upper shell changed", x, y)
            assert ap[x, y] == sp[x, y], ("active upper shell changed", x, y)
        for y in range(b + 1, H):
            # Every lower pixel is new material and every one is masked.
            assert mp[x, y][3] == 255, ("lower hole", x, y)
            assert bp[x, y] != sp[x, y], ("old lower pixel reused in base", x, y)
            assert ap[x, y] != sp[x, y], ("old lower pixel reused in active", x, y)
            assert bp[x, y] != ap[x, y], ("states identical", x, y)
    # The mask must reach the last row and both outer columns.
    for x in range(W):
        assert mp[x, H - 1][3] == 255, ("bottom row not exposed", x)
    for y in range(H):
        if mp[0, y][3] == 255:
            assert y > boundary[0], ("left frame leaked", y)
    # No original lower stone tone is used as an ore tone.
    forbidden = {
        (76, 67, 73), (94, 82, 87), (135, 121, 118), (136, 122, 119),
        (134, 120, 117), (147, 133, 131), (131, 117, 115), (126, 112, 111),
        (171, 159, 150), (141, 126, 123), (98, 87, 91), (106, 95, 97),
        (111, 98, 100), (189, 177, 166), (185, 174, 162), (170, 158, 149),
        (166, 153, 145), (165, 152, 144), (162, 150, 142), (158, 145, 137),
    }
    for x in range(W):
        for y in range(boundary[x] + 1, H):
            assert bp[x, y][:3] not in forbidden, ("old stone tone in ore", x, y)
            assert ap[x, y][:3] not in forbidden, ("old stone tone in active ore", x, y)
    return


base, active, mask, info = build()
validate(base, active, mask, info)
base.save(BASE_OUT)
active.save(ACTIVE_OUT)
mask.save(MASK_OUT)

manifest = {
    "title": "L2 ConductiveRoof ore-material revision",
    "created": "2026-11-18",
    "status": "revision after user rejection of the first layered draft; draft for review",
    "source_roof": {
        "file": "assets/level02_conductive_stone/conductive_roof_256x32.png",
        "sha256": hashlib.sha256(ROOF.read_bytes()).hexdigest(),
        "untouched": True,
    },
    "license": "Original pixel art authored in this project; source roof read only; no third-party pixels copied.",
    "reference_note": (
        "Terraria Amethyst underground/rock/stone-block images were checked by "
        "the coordinator and viewed here as analysis only. Only the idea of a "
        "dark mother rock with uneven embedded small crystal faces and limited "
        "tone steps is borrowed; no reference pixel, palette, cluster shape or "
        "gameplay is copied. The force-tint behaviour remains this project's "
        "user-originated request, not a reference-game claim."
    ),
    "layers": {
        "inactive": {
            "file": BASE_OUT.name,
            "role": "faint grey-black mineral faces; full lower layer to x0/x255 and row 31",
            "sha256": hashlib.sha256(BASE_OUT.read_bytes()).hexdigest(),
        },
        "active": {
            "file": ACTIVE_OUT.name,
            "role": "dark-purple mineral faces; same geometry as inactive",
            "sha256": hashlib.sha256(ACTIVE_OUT.read_bytes()).hexdigest(),
        },
        "mask": {
            "file": MASK_OUT.name,
            "role": "a=exposed lower material; r=crystal body response; g=highlight response",
            "sha256": hashlib.sha256(MASK_OUT.read_bytes()).hexdigest(),
        },
    },
    "geometry": info,
    "palette": {
        "inactive_mother": INACTIVE_MOTHER,
        "inactive_crystal": INACTIVE_CRYSTAL,
        "active_mother": ACTIVE_MOTHER,
        "active_crystal": ACTIVE_CRYSTAL,
        "shadow_inactive": SHADOW_INACTIVE,
        "shadow_active": SHADOW_ACTIVE,
    },
    "design_notes": [
        "No old lower stone frame, bottom lip, cavity side wall or original gold corner remains; lower pixels are new ore and checked against the source lower palette.",
        "Upper shell rows 0..boundary are copied verbatim from the original roof; boundary values and 256x32 geometry are unchanged.",
        "Lower material reaches all 256 columns and row 31. The outer two columns are new dark mineral side planes, not old stone.",
        "Ore is a dark mother rock with 12 hand-shaped cluster silhouettes placed at uneven gaps, some grouped; 2..5 px clusters with deep/mid/light facets and rare highlights.",
        "No smooth gradient fill, no regular Voronoi/line net, no repeated diamond tile and no per-pixel dot noise as the main texture.",
        "Inactive faces are faint grey-black; active faces are dark purple. Neither state is a flat bright panel.",
    ],
    "regenerate": "D:/minic/envs/2024212971/python.exe make_layered_core_ore_material.py",
}
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: info[k] for k in (
    "clusters", "crystal_pixels", "highlight_pixels", "lower_min_px", "lower_max_px",
    "upper_shell_min_px", "upper_shell_max_px", "mask_pixels",
    "left_edge_mask", "right_edge_mask", "bottom_row_mask",
)}, ensure_ascii=False))
print("inactive", hashlib.sha256(BASE_OUT.read_bytes()).hexdigest())
print("active", hashlib.sha256(ACTIVE_OUT.read_bytes()).hexdigest())
print("mask", hashlib.sha256(MASK_OUT.read_bytes()).hexdigest())
