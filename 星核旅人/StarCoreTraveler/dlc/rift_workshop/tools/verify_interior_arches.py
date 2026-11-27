"""Verify that the DLC2 arch interiors are no longer black holes.

Usage:
    D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/verify_interior_arches.py

Near-black is defined exactly as the acceptance prompt: max(R,G,B) < 24.
It reports the generated back layer and the three gameplay camera frames (plus
the opening mirror-hall frame when present).
"""

from __future__ import annotations

import math
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DLC = os.path.dirname(HERE)
PROJECT = os.path.dirname(os.path.dirname(DLC))
BACK = os.path.join(DLC, "assets", "interior", "interior_back_1880x360.png")
SHOTS = os.path.join(PROJECT, "screenshots", "rift_interior_20261127")
INTRO = os.path.join(SHOTS, "after", "intro_mirror_hall.png")
INTRO_EARLY = os.path.join(
    PROJECT, "screenshots", "rift_opening_20261127", "01_mirror_hall_wide.png"
)


def arch_spans(x0: int, y0: int, x1: int, y1: int):
    cx = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0
    spring = y0 + half
    for y in range(y0, y1 + 1):
        if y < spring:
            dy = spring - y
            h = math.sqrt(max(half * half - dy * dy, 0.0))
        else:
            h = half
        yield y, int(round(cx - h)), int(round(cx + h))


def ratio(image: Image.Image, x0: int, y0: int, x1: int, y1: int) -> tuple[int, int, float]:
    px = image.load()
    total = 0
    near_black = 0
    for y, left, right in arch_spans(x0, y0, x1, y1):
        for x in range(left, right + 1):
            r, g, b = px[x, y][:3]
            total += 1
            if max(r, g, b) < 24:
                near_black += 1
    pct = 0.0 if total == 0 else 100.0 * near_black / total
    return near_black, total, pct


def main() -> None:
    back = Image.open(BACK).convert("RGB")
    cases: list[tuple[str, Image.Image, int, int, int, int]] = [
        ("asset entry", back, 150, 100, 284, 297),
        ("asset giant", back, 612, 98, 998, 297),
        ("asset mirror1", back, 1264, 80, 1408, 293),
        ("asset mirror2", back, 1468, 80, 1612, 293),
        ("asset mirror3", back, 1672, 80, 1816, 293),
    ]
    # Gameplay frames: the back layer offsets are 0.90 * (camera view left).
    # start: view left 0; mid: 460; boss: 1110 (player x=780 / 1430).
    frame_regions = {
        "start.png": [("game start entry", 150, 100, 284, 297)],
        "mid.png": [("game mid giant", 198, 98, 584, 297)],
        "boss.png": [
            ("game boss mirror1", 265, 80, 409, 293),
            ("game boss mirror2", 469, 80, 613, 293),
        ],
    }
    for name, regions in frame_regions.items():
        path = os.path.join(SHOTS, "after", name)
        if not os.path.exists(path):
            continue
        image = Image.open(path).convert("RGB")
        for label, x0, y0, x1, y1 in regions:
            cases.append((label, image, x0, y0, x1, y1))
    if os.path.exists(INTRO):
        intro = Image.open(INTRO).convert("RGB")
        # Opening camera centre 1540 -> view left 1220 -> back offset 1098.
        cases.append(("intro 2.35 mirror1", intro, 166, 80, 310, 293))
        cases.append(("intro 2.35 mirror2", intro, 370, 80, 514, 293))
    if os.path.exists(INTRO_EARLY):
        intro_early = Image.open(INTRO_EARLY).convert("RGB")
        # The first beat is under the film's 0.50 dark grade; include it so the
        # asset cannot pass only at the end of the hold.
        cases.append(("intro 0.72 mirror1", intro_early, 166, 80, 310, 293))
        cases.append(("intro 0.72 mirror2", intro_early, 370, 80, 514, 293))

    worst = 0.0
    for label, image, x0, y0, x1, y1 in cases:
        near_black, total, pct = ratio(image, x0, y0, x1, y1)
        worst = max(worst, pct)
        print(f"{label:20s} near_black={near_black:6d}/{total:6d}  {pct:6.2f}%")
    print(f"WORST {worst:.2f}%  (limit 40%)")
    if worst > 40.0:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
