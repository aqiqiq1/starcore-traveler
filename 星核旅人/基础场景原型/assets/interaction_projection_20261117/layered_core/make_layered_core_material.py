#!/usr/bin/env python3
"""Build the L2 ConductiveRoof layered stone-shell / exposed-core cover.

Run with the project Conda Python (Pillow only):

    D:/minic/envs/2024212971/python.exe \
      assets/interaction_projection_20261117/layered_core/make_layered_core_material.py

Outputs, next to this script:
  layered_core_base_256x32.png   full 256x32 opaque cover: original upper stone
                                 rows kept verbatim, authored recessed lower
                                 star-core material (neutral dark, no cracks)
  layered_core_mask_256x32.png   white = exposed lower star-core material only
  manifest.json                  hashes, thickness ranges, boundaries, notes

Design boundary (user-approved 2026-11-18):
  - upper stone shell about 17..21 px thick, lower exposed core 11..15 px;
  - the lower material is inset 3 px inside the beam's left/right stone ends;
  - an irregular, hand-run junction with a one-pixel shell underside shadow
    and a one-pixel cavity side wall; no repeated sawtooth, no crack network,
    no standalone black bar under the platform;
  - the source roof PNG is only read/hashed and is never modified.

This is original pixel art authored in this project. The Celeste Core Block
reference was consulted by the coordinator only for shell/inner-material
separation and limited colour steps; no reference pixel is copied here.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]
ROOF = PROJECT / "assets" / "level02_conductive_stone" / "conductive_roof_256x32.png"
BASE_OUT = HERE / "layered_core_base_256x32.png"
MASK_OUT = HERE / "layered_core_mask_256x32.png"
MANIFEST = HERE / "manifest.json"

W, H = 256, 32
SIDE_FRAME = 3          # stone columns kept at both beam ends
CAVITY_INSET = 3        # first shadow/cavity column (same as SIDE_FRAME)
BOTTOM_LIP = 1          # original bottom stone outline kept under the cavity
CORE_BOTTOM = H - 1 - BOTTOM_LIP
SHADOW = (46, 38, 43, 255)
SHADOW_ALT = (57, 47, 51, 255)
CAVITY_WALL = (39, 32, 37, 255)
CHIP = (124, 111, 104, 255)
CHIP_LIGHT = (158, 144, 134, 255)

# Hand-run junction lengths/values. Uneven runs, plateaus and occasional 2 px
# drops; no periodic/sine step. Values are the last upper-shell row index, so
# shell thickness is value+1 px and lower exposed height is 31-value px.
RUNS = [
    (5, 18), (8, 17), (12, 18), (6, 19), (7, 18), (11, 19), (4, 20),
    (9, 19), (13, 18), (5, 17), (10, 18), (9, 20), (6, 19), (12, 19),
    (7, 18), (8, 18), (5, 17), (11, 18), (9, 19), (6, 18), (13, 20),
    (8, 19), (4, 18), (10, 17), (7, 18), (9, 19), (6, 20), (12, 19),
    (8, 18), (5, 17), (11, 18), (7, 19), (13, 18), (6, 17), (4, 18),
]
# Sparse chipped shell lip pixels on the junction (not a continuous outline).
CHIP_PX = {18, 53, 91, 129, 166, 205, 238}
CHIP_LIGHT_PX = {34, 112, 221}


def build_boundary() -> list[int]:
    values: list[int] = []
    for length, value in RUNS:
        values.extend([value] * length)
    if len(values) < W:
        values.extend([values[-1]] * (W - len(values)))
    values = values[:W]
    # A few non-periodic 1 px offsets keep the edge from reading as machine
    # steps. They change the last-shell row by at most one pixel.
    for x in (7, 26, 44, 63, 78, 104, 121, 143, 158, 181, 199, 217, 233, 249):
        if CAVITY_INSET < x < W - CAVITY_INSET:
            values[x] = min(20, values[x] + 1)
    return values


def value_noise(x: float, y: float) -> float:
    """Deterministic coarse value noise, 0..1, no third-party data."""
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


def build() -> tuple[Image.Image, Image.Image, dict]:
    src = Image.open(ROOF).convert("RGBA")
    assert src.size == (W, H), src.size
    boundary = build_boundary()
    assert all(17 <= b <= 20 for b in boundary)
    assert min(boundary) + 1 >= 18 and max(boundary) + 1 <= 21
    assert CORE_BOTTOM - max(boundary) >= 9 and CORE_BOTTOM - min(boundary) <= 15

    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bp = base.load()
    mp = mask.load()
    sp = src.load()

    for x in range(W):
        b = boundary[x]
        # Preserve the original stone exactly in the upper shell and at the
        # side frame; only rows at/below the junction are replaced.
        for y in range(0, b + 1):
            bp[x, y] = sp[x, y]
        for y in range(H):
            if x < SIDE_FRAME or x >= W - SIDE_FRAME:
                bp[x, y] = sp[x, y]

        # Shell underside shadow, one pixel, continuous with the shell.
        if SIDE_FRAME <= x < W - SIDE_FRAME:
            bp[x, b] = SHADOW_ALT if (x % 29 in (4, 17)) else SHADOW

        # Sparse chipped lip sits on the shadow row, not a floating outline.
        if x in CHIP_PX:
            bp[x, b] = CHIP_LIGHT if x in CHIP_LIGHT_PX else CHIP

        # Recessed cavity walls at the two inner frame columns.
        if x in (SIDE_FRAME, W - SIDE_FRAME - 1):
            for y in range(b + 1, CORE_BOTTOM + 1):
                bp[x, y] = CAVITY_WALL

        # Exposed lower star-core material. Neutral dark mineral mottle; the
        # shader supplies black / dark purple and the local tint. No crack,
        # vein, line, or geometric network is drawn here.
        if SIDE_FRAME < x < W - SIDE_FRAME - 1:
            for y in range(b + 1, CORE_BOTTOM + 1):
                depth = (y - b) / float(CORE_BOTTOM - b)
                n = value_noise(x / 23.0, y / 6.5)
                luma = 0.100 + 0.070 * n
                if y == b + 1:
                    luma *= 1.42          # inner upper lip catches a little light
                if y == CORE_BOTTOM:
                    luma *= 0.78          # material sinks toward the stone lip
                luma += 0.014 * depth
                v = max(0, min(255, int(round(luma * 255.0))))
                bp[x, y] = (v, v, v, 255)
                mp[x, y] = (255, 255, 255, 255)

    # Original bottom stone outline stays intact under the recessed cavity.
    for x in range(W):
        bp[x, H - 1] = sp[x, H - 1]

    # A few isolated single mineral flecks, never joined into lines or a grid.
    for x, fy in ((37, 0.30), (86, 0.62), (139, 0.44), (188, 0.72), (226, 0.36)):
        b = boundary[x]
        y = b + 1 + int(round(fy * (CORE_BOTTOM - 1 - b)))
        if b + 1 <= y <= CORE_BOTTOM - 1:
            px = bp[x, y]
            bp[x, y] = (min(255, px[0] + 16), min(255, px[1] + 13),
                        min(255, px[2] + 16), 255)

    info = {
        "boundary_min": min(boundary),
        "boundary_max": max(boundary),
        "upper_shell_px_min": min(boundary) + 1,
        "upper_shell_px_max": max(boundary) + 1,
        "lower_core_px_min": CORE_BOTTOM - max(boundary),
        "lower_core_px_max": CORE_BOTTOM - min(boundary),
        "bottom_stone_lip_px": BOTTOM_LIP,
        "cavity_x_min": SIDE_FRAME + 1,
        "cavity_x_max": W - SIDE_FRAME - 2,
        "mask_pixels": sum(1 for y in range(H) for x in range(W) if mp[x, y][3] > 0),
        "shadow_pixels": sum(1 for x in range(SIDE_FRAME, W - SIDE_FRAME)
                             if bp[x, boundary[x]][:3] in (SHADOW[:3], SHADOW_ALT[:3])),
        "chip_pixels": len(CHIP_PX),
        "boundary": boundary,
    }
    return base, mask, info


def validate(base: Image.Image, mask: Image.Image, info: dict) -> None:
    src = Image.open(ROOF).convert("RGBA")
    sp, bp, mp = src.load(), base.load(), mask.load()
    boundary = info["boundary"]
    assert base.size == (W, H) and mask.size == (W, H)
    assert info["mask_pixels"] > 2000, info
    assert 9 <= info["lower_core_px_min"] <= info["lower_core_px_max"] <= 15, info
    assert 18 <= info["upper_shell_px_min"] <= info["upper_shell_px_max"] <= 21, info
    # The original bottom stone outline is untouched for every column.
    for x in range(W):
        assert bp[x, H - 1] == sp[x, H - 1], ("bottom outline changed", x)
    for x in range(W):
        b = boundary[x]
        for y in range(b):
            if 0 <= x < W:
                assert bp[x, y] == sp[x, y], ("upper not preserved", x, y)
        if x < SIDE_FRAME or x >= W - SIDE_FRAME:
            for y in range(H):
                assert bp[x, y] == sp[x, y], ("side frame not preserved", x, y)
    # No mask pixel may exist in the shell or side frame.
    for x in range(W):
        for y in range(H):
            if x < SIDE_FRAME or x >= W - SIDE_FRAME or y <= boundary[x]:
                assert mp[x, y][3] == 0, ("mask leaked into stone", x, y)
    # The mask is one continuous cavity under an irregular top edge, not a
    # crack network: every cavity column is filled from its own boundary down
    # to the beam bottom, with no holes.
    for x in range(SIDE_FRAME + 1, W - SIDE_FRAME - 1):
        b = boundary[x]
        for y in range(H):
            expected = b + 1 <= y <= CORE_BOTTOM
            assert (mp[x, y][3] > 0) == expected, ("mask column hole", x, y)
    return


base, mask, info = build()
validate(base, mask, info)
base.save(BASE_OUT)
mask.save(MASK_OUT)

manifest = {
    "title": "L2 ConductiveRoof layered stone shell / exposed star-core material",
    "created": "2026-11-18",
    "status": "draft for user review (not final art approval)",
    "source_roof": {
        "file": "assets/level02_conductive_stone/conductive_roof_256x32.png",
        "sha256": hashlib.sha256(ROOF.read_bytes()).hexdigest(),
        "untouched": True,
    },
    "license": "Original pixel art authored in this project; source roof read only; no third-party pixels copied.",
    "reference_note": (
        "Celeste Core Block hot/cold GIFs were checked by the coordinator for "
        "shell/inner-material separation, thin edge light and limited colour "
        "steps only. No Celeste pixel, lava/ice palette or gameplay is copied; "
        "the local amulet-tint behaviour is the user's original request."
    ),
    "layers": {
        "base": {
            "file": BASE_OUT.name,
            "role": "full 256x32 opaque cover; original upper stone rows kept, authored recessed lower core",
            "sha256": hashlib.sha256(BASE_OUT.read_bytes()).hexdigest(),
        },
        "mask": {
            "file": MASK_OUT.name,
            "role": "white only on exposed lower core; shader never tints the stone shell",
            "sha256": hashlib.sha256(MASK_OUT.read_bytes()).hexdigest(),
        },
    },
    "geometry": info,
    "design_notes": [
        "Upper shell 18..21 px, lower exposed star-core material 10..13 px, total beam 256x32.",
        "Junction is made of hand-run lengths 4..13 px and values 17..20: plateaus, uneven steps, occasional 2 px relief; no periodic sawtooth.",
        "Lower material is inset 3 px at each beam end and kept above the original 1 px bottom stone outline, with a 1 px shell underside shadow and 1 px cavity side walls; no standalone black bar.",
        "Lower material is neutral dark mottle only: no cracks, veins, lines, glyphs or network.",
        "Sparse junction chips are 7 single pixels; they are not a continuous outline.",
    ],
    "regenerate": "D:/minic/envs/2024212971/python.exe make_layered_core_material.py",
}
MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: info[k] for k in (
    "boundary_min", "boundary_max", "upper_shell_px_min", "upper_shell_px_max",
    "lower_core_px_min", "lower_core_px_max", "bottom_stone_lip_px",
    "cavity_x_min", "cavity_x_max", "mask_pixels", "shadow_pixels", "chip_pixels",
)}, ensure_ascii=False))
print("base", hashlib.sha256(BASE_OUT.read_bytes()).hexdigest())
print("mask", hashlib.sha256(MASK_OUT.read_bytes()).hexdigest())
