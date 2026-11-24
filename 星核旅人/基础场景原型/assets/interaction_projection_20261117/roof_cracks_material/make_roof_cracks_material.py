#!/usr/bin/env python3
"""Build the fine multi-block crack network for the L2 ConductiveRoof.

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/roof_cracks_material/make_roof_cracks_material.py

Outputs, next to this script:
  roof_cracks_dark_256x32.png  thin crack cores + direction-aware soft shadow + sparse stone lip
  roof_cracks_glow_256x32.png  purple hairline network (mid main, some deep, few pale)
  manifest.json                counts, bounds, palette, hashes, block notes

The previous refine overlay is archived in `previous_refine_20261118/` and the
first material in `previous_20261118/`; neither is overwritten here. This is
original pixel art: every fragment is hand-placed inside one stone block, not
a translated/mirrored copy. The source roof PNG is only hashed.
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
TOP_LIMIT, BOTTOM_LIMIT = 2, 29

# Hand-placed 1 px cracks. Blocks: top y0-10 (seams x96,176), brick band y14-20
# (seams x0,72,152,216), lip y23-24 (seams x96,160), base y25-31 (x96,160).
# No fragment crosses a block boundary or reaches the roof top/bottom.
FRAGS = [
    # top-left block 0..95
    {"id": "A1", "px": [(20,9),(21,9),(22,8),(23,8),(24,7),(25,7),(26,6),(27,6),(28,5),(29,5)],
     "tones": "MMDMMMMPDM"},
    {"id": "A2", "px": [(38,7),(39,7),(40,7),(41,6),(42,6),(43,6),(44,6)], "tones": "DMMDMMM"},
    {"id": "A3", "px": [(24,8),(23,9),(22,10)], "tones": "DMX"},
    # top-middle block 97..175
    {"id": "B1", "px": [(110,6),(111,6),(112,7),(113,7),(114,8),(115,8),(116,9),(117,9)],
     "tones": "MMDMMPDM"},
    {"id": "B2", "px": [(132,9),(133,8),(134,8),(135,7),(136,7),(137,6),(138,6)], "tones": "DMMDMMM"},
    {"id": "B3", "px": [(122,7),(123,7),(124,6),(125,6)], "tones": "MDMM"},
    # top-right block 177..255
    {"id": "C1", "px": [(196,9),(196,8),(197,7),(197,6),(198,5),(198,4)], "tones": "MMDMPM"},
    # brick band 1..71
    {"id": "D1", "px": [(10,18),(11,18),(12,18),(13,17),(14,17),(15,17),(16,16),(17,16)],
     "tones": "MMDMMPDM"},
    # brick band 73..151
    {"id": "E1", "px": [(86,16),(87,16),(88,17),(89,17),(90,18),(91,18),(92,19)], "tones": "MMDMMDM"},
    {"id": "E2", "px": [(89,18),(88,19),(87,19)], "tones": "DMX"},
    {"id": "E3", "px": [(110,14),(111,15),(112,15),(113,16)], "tones": "MDMM"},
    # brick band 153..215
    {"id": "F1", "px": [(170,19),(170,18),(170,17),(171,16),(171,15),(172,15)], "tones": "DMMDMM"},
    # lip band
    {"id": "H1", "px": [(30,23),(31,23),(32,24),(33,24),(34,23)], "tones": "MDMMM"},
    {"id": "H2", "px": [(180,24),(181,23),(182,23),(183,24),(184,24)], "tones": "DMMPM"},
    # base 0..95
    {"id": "I1", "px": [(44,28),(45,28),(46,28),(47,27),(48,27),(49,27),(50,26),(51,26),(52,26)],
     "tones": "MMMMDMPDM"},
    {"id": "I2", "px": [(47,28),(46,29),(45,29)], "tones": "DMM"},
    {"id": "I3", "px": [(70,27),(71,26),(72,26),(73,25),(74,25)], "tones": "MMDMM"},
    # base 161..255
    {"id": "K1", "px": [(230,28),(231,28),(232,27),(233,27),(234,27),(235,26)], "tones": "MMDMMX"},
]

# Sparse local chipped lip; not an outline on every crack.
LIP_PX = [
    (19,9), (30,4), (45,7), (118,9), (139,6), (199,4),
    (9,18), (93,19), (173,15), (43,28), (53,26), (185,24),
]
LIP_BRIGHT_IDX = {0, 3, 6, 9}

DARK_CORE = (28, 20, 32, 242)
SHADOW = (58, 46, 54, 150)
LIP = (207, 194, 181, 200)
LIP_BRIGHT = (212, 199, 186, 215)
MID = (167, 93, 229, 242)    # ~#a75de5
DEEP = (122, 70, 176, 235)   # ~#7a46b0
PALE = (205, 158, 245, 246)  # a handful


def build() -> tuple[Image.Image, Image.Image, dict]:
    gap: dict[tuple[int, int], str] = {}
    tones: dict[tuple[int, int], str] = {}
    for frag in FRAGS:
        assert len(frag["px"]) == len(frag["tones"]), frag["id"]
        for (x, y), tone in zip(frag["px"], frag["tones"]):
            assert (x, y) not in gap, ("overlap", frag["id"], x, y)
            assert 0 <= x < W and TOP_LIMIT <= y <= BOTTOM_LIMIT, ("outside", frag["id"], x, y)
            gap[(x, y)] = frag["id"]
            tones[(x, y)] = tone

    lip: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for i, (x, y) in enumerate(LIP_PX):
        assert (x, y) not in gap, ("lip on crack", x, y)
        assert TOP_LIMIT <= y <= BOTTOM_LIMIT, ("lip outside", x, y)
        lip[(x, y)] = LIP_BRIGHT if i in LIP_BRIGHT_IDX else LIP

    # One soft shadow pixel on the lower/right side, following the local
    # direction. It is a groove edge, not a second black core.
    shadow: dict[tuple[int, int], tuple[int, int, int, int]] = {}
    for frag in FRAGS:
        px = frag["px"]
        for i, (x, y) in enumerate(px):
            if i + 1 < len(px):
                nx, ny = px[i + 1]
            elif len(px) > 1:
                nx, ny = px[i - 1]
            else:
                continue
            dx, dy = nx - x, ny - y
            q = (x, y + 1) if abs(dx) >= abs(dy) else (x + 1, y)
            if q not in gap and q not in lip and TOP_LIMIT <= q[1] <= BOTTOM_LIMIT:
                shadow[q] = SHADOW

    dark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dp = dark.load()
    for (x, y) in gap:
        dp[x, y] = DARK_CORE
    for (x, y), color in lip.items():
        dp[x, y] = color
    for (x, y), color in shadow.items():
        dp[x, y] = color

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gp = glow.load()
    for (x, y), tone in tones.items():
        if tone == "M":
            gp[x, y] = MID
        elif tone == "D":
            gp[x, y] = DEEP
        elif tone == "P":
            gp[x, y] = PALE
        # X stays dark: a deliberate break in the lit network.

    info = {
        "fragments": len(FRAGS),
        "core_pixels": len(gap),
        "shadow_pixels": len(shadow),
        "lip_pixels": len(lip),
        "glow_pixels": sum(1 for t in tones.values() if t != "X"),
        "mid_pixels": sum(1 for t in tones.values() if t == "M"),
        "deep_pixels": sum(1 for t in tones.values() if t == "D"),
        "pale_pixels": sum(1 for t in tones.values() if t == "P"),
        "dark_break_pixels": sum(1 for t in tones.values() if t == "X"),
    }
    return dark, glow, info


def alpha_bounds(img: Image.Image) -> dict:
    px = img.load()
    pts = [(x, y) for y in range(H) for x in range(W) if px[x, y][3] > 0]
    return {
        "pixels": len(pts),
        "alpha_min": min(px[x, y][3] for x, y in pts),
        "alpha_max": max(px[x, y][3] for x, y in pts),
        "x_min": min(x for x, _ in pts), "x_max": max(x for x, _ in pts),
        "y_min": min(y for _, y in pts), "y_max": max(y for _, y in pts),
    }


def validate(dark: Image.Image, glow: Image.Image, info: dict) -> None:
    gap = {(x, y) for frag in FRAGS for (x, y) in frag["px"]}
    for name, img in (("dark", dark), ("glow", glow)):
        assert img.size == (W, H), name
        b = alpha_bounds(img)
        assert TOP_LIMIT <= b["y_min"] and b["y_max"] <= BOTTOM_LIMIT, (name, b)
        assert 0 <= b["x_min"] and b["x_max"] < W, (name, b)
        px = img.load()
        for y in range(H):
            for x in range(W):
                if px[x, y][3] == 0:
                    continue
                near = any((x + dx, y + dy) in gap
                           for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                assert near, (name, "too far from a crack", x, y)
    assert info["core_pixels"] > 0 and info["glow_pixels"] > 0, info
    assert info["mid_pixels"] > info["deep_pixels"] > info["pale_pixels"], info


dark, glow, info = build()
validate(dark, glow, info)
dark.save(DARK_OUT)
glow.save(GLOW_OUT)

manifest = {
    "title": "L2 ConductiveRoof fine multi-block crack network",
    "created": "2026-11-18",
    "status": "complete redesign after the refine version was rejected; 18 hand-placed hairline fragments, no three main trunks",
    "previous_refine": "previous_refine_20261118/ (kept unchanged, marked superseded)",
    "previous_first_material": "previous_20261118/ (kept unchanged)",
    "placement": "Aligned 1:1 with assets/level02_conductive_stone/conductive_roof_256x32.png; overlay only, source PNG untouched.",
    "license": "Original pixel art authored in this project; no third-party pixels.",
    "reference_exemption": "Only this L2 activation presentation uses the user's note-7e10 direct-trial exemption; no mechanism reference was checked or claimed.",
    "layers": {
        "dark": {
            "file": DARK_OUT.name,
            "role": "1 px crack cores + one direction-aware soft shadow pixel + sparse chipped stone lip; always drawn while locked",
            "sha256": hashlib.sha256(DARK_OUT.read_bytes()).hexdigest(),
            "alpha_bounds": alpha_bounds(dark),
            "palette": {"core": DARK_CORE, "shadow": SHADOW, "lip": LIP, "lip_bright": LIP_BRIGHT},
        },
        "glow": {
            "file": GLOW_OUT.name,
            "role": "purple hairline network, mid main / some deep / few pale; revealed 0.52-0.80 s and held",
            "sha256": hashlib.sha256(GLOW_OUT.read_bytes()).hexdigest(),
            "alpha_bounds": alpha_bounds(glow),
            "palette": {"mid": MID, "deep": DEEP, "pale": PALE},
        },
    },
    "source_roof": {"file": str(ROOF.relative_to(PROJECT)).replace("\\", "/"),
                    "sha256": hashlib.sha256(ROOF.read_bytes()).hexdigest()},
    "counts": info,
    "design_notes": [
        "18 hand-placed fragments, 4-10 px, inside individual top/brick/lip/base blocks; no crack crosses a joint or spans the platform.",
        "No three vertical main trunks, no equidistant crack centers, no equal-length anchor per group. A1 (10 px), C1/I1 (7-9 px), and short 4-6 px fragments differ in orientation and length.",
        "Mixed orientations: up-right, down-right, horizontal, vertical; no translated or mirrored duplicate.",
        "Local pairs/branches exist (A1+A3, E1+E2, I1+I2, B1/B2/B3) and other areas are left blank. No tree/lightning/circuit/text motif.",
        "Most cracks are 1 px with a 1 px semi-transparent shadow; no 2-3 px black main body and no full-length lip outline. 12 sparse lip pixels only.",
        "Glow: mid main, some deep, few pale, with a few deliberate dark breaks; the purple network is the first visual impression, not 2-3 bright spots.",
        "All material is inside y4..29 (>=2 px from the roof top/bottom outline).",
    ],
    "regenerate": "D:/minic/envs/2024212971/python.exe make_roof_cracks_material.py",
}
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(info, ensure_ascii=False))
print("dark", alpha_bounds(dark), hashlib.sha256(DARK_OUT.read_bytes()).hexdigest())
print("glow", alpha_bounds(glow), hashlib.sha256(GLOW_OUT.read_bytes()).hexdigest())
