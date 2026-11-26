"""DLC3 city-interior art pass v2 (2026-11-27).

Creates a new runtime set under dlc/star_loom/assets/city_v2/ without touching
the earlier dlc/star_loom/assets/city/ files.

Goals from the six-chapter audit:
  * same stone palette as the approved bridge_stone_v1 / doric column family;
  * three identical arched windows, glass showing the DS03 cloud sky (no
    near-black panes / random holes);
  * a wall/floor junction with an explicit plinth, contact shadow and 1 px
    top light;
  * cornice, pilaster capitals/bases and gold trim sharing one 1-2 px scale;
  * calmer grain density and larger calm wall fields;
  * top-left key light, warm firelight only as a local accent.

Original procedural pixel art only. No external image, palette or sprite is
read. The classic-game references in REFERENCE_LOG_20261127.md were studied by
the author, not traced or sampled.

Run:
    D:/minic/envs/2024212971/python.exe dlc/star_loom/tools/gen_city_assets_v2.py
"""

from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DLC = os.path.dirname(HERE)
OUT = os.path.join(DLC, "assets", "city_v2")

# ---------------------------------------------------------------------------
# Shared palette.  Stone values are sampled from the approved bridge_stone_v1
# runtime art; sky/sea values from the DS03 background; gold/cyan/purple from
# PRESENTATION_SYSTEM.md.  Interior shadows add a cold violet bias.
# ---------------------------------------------------------------------------
INK = (20, 18, 22, 255)
MORTAR = (55, 47, 52, 255)
STONE_DARK = (60, 52, 60, 255)
STONE_0 = (76, 67, 73, 255)
STONE_1 = (94, 82, 87, 255)
STONE_2 = (112, 99, 101, 255)
STONE_3 = (124, 110, 109, 255)
STONE_4 = (136, 122, 120, 255)
STONE_5 = (147, 132, 127, 255)
STONE_6 = (159, 146, 138, 255)
STONE_7 = (172, 160, 151, 255)
STONE_HI = (190, 180, 168, 255)
STONE_TOP = (198, 187, 174, 255)
SHADOW = (52, 46, 54, 255)
SHADOW_SOFT = (64, 56, 64, 255)

SKY_TOP = (45, 90, 112, 255)
SKY_MID = (80, 125, 141, 255)
SKY_LOW = (120, 165, 174, 255)
CLOUD_DARK = (105, 145, 156, 255)
CLOUD = (133, 173, 181, 255)
CLOUD_LIGHT = (163, 195, 200, 255)

GOLD = (244, 205, 99, 255)
GOLD_MID = (212, 166, 74, 255)
GOLD_DARK = (126, 92, 36, 255)
BRASS = (150, 112, 48, 255)
IRON = (36, 34, 40, 255)
IRON_LIGHT = (96, 90, 88, 255)

PURPLE = (185, 140, 255, 255)
PURPLE_DARK = (66, 34, 96, 255)
DRAPE = (40, 26, 54, 255)
DRAPE_DARK = (27, 17, 38, 255)
CYAN = (95, 225, 230, 255)
CYAN_DARK = (36, 104, 112, 255)
WHITE_WARM = (255, 248, 224, 255)


def px(draw: ImageDraw.ImageDraw, x: int, y: int, color) -> None:
    if 0 <= x < draw.im.size[0] and 0 <= y < draw.im.size[1]:
        draw.point((x, y), fill=color)


def rect(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, color) -> None:
    draw.rectangle((x0, y0, x1, y1), fill=color)


def disc(draw: ImageDraw.ImageDraw, cx: float, cy: float, r: float, color) -> None:
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(draw, x, y, color)


def blend_rect(image: Image.Image, box, color, alpha: int) -> None:
    """Opaque stepped lighten/darken; keeps the asset palette-indexed."""
    if alpha <= 0:
        return
    x0, y0, x1, y1 = box
    draw = ImageDraw.Draw(image)
    for y in range(max(0, y0), min(image.height, y1 + 1)):
        for x in range(max(0, x0), min(image.width, x1 + 1)):
            cur = image.getpixel((x, y))
            if cur[3] == 0:
                continue
            draw.point((x, y), fill=(
                cur[0] + (color[0] - cur[0]) * alpha // 255,
                cur[1] + (color[1] - cur[1]) * alpha // 255,
                cur[2] + (color[2] - cur[2]) * alpha // 255,
                255,
            ))


def arch_spans(x0: int, y0: int, x1: int, y1: int):
    """Yield (y, left, right) for a round-arched opening, inclusive."""
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


def arch_ring(image: Image.Image, x0, y0, x1, y1, inset, color) -> None:
    draw = ImageDraw.Draw(image)
    # The bottom edge stays at y1 so the frame meets the sill; only the top
    # and sides are inset/outset.
    for y, left, right in arch_spans(x0 + inset, y0 + inset, x1 - inset, y1):
        rect(draw, left, y, right, y, color)


def brick_wall(image: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    """Calm 48x24 coursing in the bridge_stone_v1 grey-mauve family."""
    draw = ImageDraw.Draw(image)
    rng = random.Random(20261127)
    rect(draw, x0, y0, x1, y1, STONE_1)
    course = 24
    brick = 48
    row = 0
    y = y0
    while y <= y1:
        h = min(course, y1 - y + 1)
        rect(draw, x0, y, x1, y + h - 1, STONE_1)
        # 1 px top light, 1 px bottom mortar: same joint language as L2.
        rect(draw, x0, y, x1, y, STONE_2)
        offset = 0 if row % 2 == 0 else brick // 2
        bx = x0 - offset
        while bx < x1:
            tone = rng.choice((STONE_0, STONE_1, STONE_1, STONE_2))
            bx0 = max(x0, bx + 1)
            bx1 = min(x1, bx + brick - 2)
            if bx1 >= bx0:
                rect(draw, bx0, y + 1, bx1, y + h - 2, tone)
                # One quiet nick every few bricks, never a noise field.
                if rng.random() < 0.22:
                    nx = min(bx1 - 3, bx0 + 7)
                    px(draw, nx, y + 4, STONE_3)
                if rng.random() < 0.12:
                    nx = min(bx1 - 4, bx0 + 15)
                    px(draw, nx, y + h - 5, STONE_DARK)
            # Mortar joint at the right edge and bottom.
            if x0 <= bx + brick - 1 <= x1:
                rect(draw, bx + brick - 1, y + 1, bx + brick - 1, y + h - 2, MORTAR)
            bx += brick
        rect(draw, x0, y + h - 1, x1, y + h - 1, MORTAR)
        y += h
        row += 1
    # Broad ambient occlusion: ceiling shadow and floor shadow, 1 px steps.
    for step, color in enumerate((SHADOW_SOFT, SHADOW_SOFT, SHADOW)):
        blend_rect(image, (x0, y0 + step, x1, y0 + 3), color, 70 - step * 18)
    for step in range(4):
        blend_rect(image, (x0, y1 - step, x1, y1), SHADOW, 46 - step * 10)


def ceiling(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    # Coffered underside: shadow, beam, shadow, frieze, cornice.
    rect(draw, 0, 0, 959, 13, (28, 24, 31, 255))
    rect(draw, 0, 14, 959, 15, (38, 33, 41, 255))
    rect(draw, 0, 16, 959, 27, STONE_0)
    rect(draw, 0, 16, 959, 16, STONE_2)
    rect(draw, 0, 27, 959, 28, STONE_DARK)
    for bx in range(0, 960, 96):
        rect(draw, bx, 16, bx, 27, (46, 40, 48, 255))
        rect(draw, bx + 1, 17, bx + 1, 26, STONE_1)
    rect(draw, 0, 29, 959, 52, STONE_1)
    rect(draw, 0, 29, 959, 29, STONE_2)
    rect(draw, 0, 52, 959, 52, STONE_0)
    for bx in range(0, 960, 112):
        rect(draw, bx, 30, bx, 51, STONE_0)
        rect(draw, bx + 1, 31, bx + 1, 50, STONE_2)
    # Gold dentils: one small motif per 48 px, same 1-2 px scale as the sill.
    for bx in range(14, 960, 48):
        rect(draw, bx, 44, bx + 5, 45, GOLD_DARK)
        px(draw, bx + 2, 43, GOLD_DARK)
        px(draw, bx + 2, 42, GOLD_MID)
    # Cornice and the single 1 px gold line that separates ceiling from wall.
    rect(draw, 0, 50, 959, 53, STONE_3)
    rect(draw, 0, 50, 959, 50, STONE_5)
    rect(draw, 0, 53, 959, 53, GOLD_DARK)
    rect(draw, 0, 54, 959, 54, STONE_0)


def window_module(image: Image.Image, x0: int, y0: int) -> None:
    """One canonical 126x204 window.  All three hall bays call this with the
    same coordinates modulo translation, so their interior pixels are equal."""
    draw = ImageDraw.Draw(image)
    x1 = x0 + 125
    y1 = y0 + 203
    # 6 px stone frame, bevel toward the top-left.
    arch_ring(image, x0, y0, x1, y1, -6, STONE_2)
    arch_ring(image, x0, y0, x1, y1, -5, STONE_4)
    arch_ring(image, x0, y0, x1, y1, -4, STONE_5)
    arch_ring(image, x0, y0, x1, y1, -3, STONE_3)
    arch_ring(image, x0, y0, x1, y1, -2, STONE_1)
    arch_ring(image, x0, y0, x1, y1, -1, STONE_0)
    # Glass: vertical DS03 sky ramp, then three fixed, stepped cloud bands.
    for y, left, right in arch_spans(x0, y0, x1, y1):
        t = (y - y0) / max(1, y1 - y0)
        color = _lerp_color(SKY_TOP, SKY_LOW, t)
        rect(draw, left, y, right, y, color)
    _cloud_band(image, x0, y0, x1, y1, 46, 20, CLOUD_DARK, CLOUD, 0)
    _cloud_band(image, x0, y0, x1, y1, 92, 18, CLOUD, CLOUD_LIGHT, 7)
    _cloud_band(image, x0, y0, x1, y1, 142, 15, CLOUD_DARK, CLOUD, 13)
    # One horizon/sea suggestion near the base; not a black hole.
    for y, left, right in arch_spans(x0, y0, x1, y1):
        if y >= y1 - 22:
            rect(draw, left, y, right, y, SKY_MID)
    _cloud_band(image, x0, y0, x1, y1, 184, 9, CLOUD, CLOUD_DARK, 21)
    # Leaded glass: two vertical bars and three transoms, identical per bay.
    for gx in (x0 + 42, x0 + 84):
        rect(draw, gx, y0 + 18, gx + 1, y1 - 5, IRON)
        rect(draw, gx + 1, y0 + 18, gx + 1, y1 - 5, IRON)
        rect(draw, gx, y0 + 18, gx, y1 - 5, IRON_LIGHT)
    for gy in (y0 + 62, y0 + 126, y0 + 165):
        rect(draw, x0 + 4, gy, x1 - 4, gy, IRON)
        rect(draw, x0 + 4, gy + 1, x1 - 4, gy + 1, IRON_LIGHT)
    # Six fixed stained-glass accents per window (same indices every bay).
    accents = (
        (18, 30, PURPLE), (52, 44, CYAN_DARK), (92, 34, GOLD_DARK),
        (30, 94, CYAN_DARK), (72, 104, PURPLE_DARK), (104, 76, GOLD_MID),
    )
    for dx, dy, color in accents:
        gx = x0 + dx
        gy = y0 + dy
        rect(draw, gx, gy, gx + 2, gy + 2, color)
        px(draw, gx + 1, gy + 1, _lerp_color(color, WHITE_WARM, 0.45))
    # Inner arch shadow (2 px) and recess shadow at the right/bottom.
    for y, left, right in arch_spans(x0, y0, x1, y1):
        if y < y0 + 4:
            rect(draw, left, y, right, y, STONE_0)
    for y, left, right in arch_spans(x0, y0, x1, y1):
        rect(draw, right - 2, y, right, y, (72, 66, 74, 255))
    # Sill: 8 px proud stone + one gold line + contact shadow.
    rect(draw, x0 - 8, y1 + 1, x1 + 8, y1 + 6, STONE_DARK)
    rect(draw, x0 - 8, y1 + 1, x1 + 8, y1 + 2, STONE_5)
    rect(draw, x0 - 7, y1 + 3, x1 + 7, y1 + 4, STONE_3)
    rect(draw, x0 - 7, y1 + 5, x1 + 7, y1 + 5, GOLD_DARK)
    rect(draw, x0 - 8, y1 + 6, x1 + 8, y1 + 6, STONE_0)


def _lerp_color(a, b, t: float):
    t = max(0.0, min(1.0, t))
    return (
        int(round(a[0] + (b[0] - a[0]) * t)),
        int(round(a[1] + (b[1] - a[1]) * t)),
        int(round(a[2] + (b[2] - a[2]) * t)),
        255,
    )


def _cloud_band(
    image: Image.Image, x0: int, y0: int, x1: int, y1: int,
    top: int, height: int, base, crest, phase: int,
) -> None:
    """A fixed, stepped cloud band clipped by the window arch."""
    draw = ImageDraw.Draw(image)
    for y, left, right in arch_spans(x0, y0, x1, y1):
        rel = y - y0 - top
        if rel < 0 or rel > height:
            continue
        # Three-lobed silhouette, same phase for every window.
        for x in range(left, right + 1):
            u = (x - x0) / 126.0
            lobe = (
                math.sin(u * math.tau * 1.5 + phase * 0.53) * 4.0
                + math.sin(u * math.tau * 0.75 + phase * 0.21) * 3.0
            )
            edge = int(round(height * 0.55 + lobe))
            if rel <= edge:
                rect(draw, x, y, x, y, crest if rel <= edge - 5 else base)
            elif rel <= edge + 2:
                px(draw, x, y, base)


def pilaster(image: Image.Image, x: int, width: int = 40) -> None:
    """Pilaster family: 40 px shaft, 44 px cap/base, top-left bevel."""
    draw = ImageDraw.Draw(image)
    top = 56
    bottom = 318
    cap_x0 = x - 2
    cap_x1 = x + width + 1
    # Cast shadow on the wall to the right.
    rect(draw, cap_x1 + 1, top + 4, cap_x1 + 4, bottom, SHADOW)
    # Shaft.
    shaft_x0 = x + 6
    shaft_x1 = x + width - 7
    rect(draw, shaft_x0, top + 12, shaft_x1, bottom - 18, STONE_2)
    rect(draw, shaft_x0, top + 12, shaft_x0 + 2, bottom - 18, STONE_4)
    rect(draw, shaft_x1 - 2, top + 12, shaft_x1, bottom - 18, STONE_1)
    rect(draw, shaft_x1, top + 12, shaft_x1, bottom - 18, STONE_0)
    for fx in range(shaft_x0 + 7, shaft_x1 - 3, 7):
        rect(draw, fx, top + 16, fx, bottom - 22, STONE_1)
        px(draw, fx + 1, top + 18, STONE_3)
    # Capital: abacus, echinus, gold fillet, shadow.
    rect(draw, cap_x0, top, cap_x1, top + 5, STONE_5)
    rect(draw, cap_x0, top, cap_x1, top, STONE_7)
    rect(draw, cap_x0, top + 6, cap_x1, top + 10, STONE_4)
    rect(draw, x + 2, top + 11, x + width - 3, top + 13, STONE_3)
    rect(draw, x + 1, top + 14, x + width - 2, top + 15, GOLD_DARK)
    rect(draw, x + 2, top + 16, x + width - 3, top + 17, STONE_0)
    # Base: torus, plinth, gold pin, dark contact.
    rect(draw, x + 2, bottom - 21, x + width - 3, bottom - 14, STONE_3)
    rect(draw, x + 2, bottom - 21, x + width - 3, bottom - 20, STONE_5)
    rect(draw, cap_x0, bottom - 13, cap_x1, bottom - 4, STONE_4)
    rect(draw, cap_x0, bottom - 13, cap_x1, bottom - 13, STONE_6)
    rect(draw, x + 3, bottom - 9, x + width - 4, bottom - 9, GOLD_DARK)
    rect(draw, cap_x0, bottom - 3, cap_x1, bottom, STONE_0)
    rect(draw, cap_x0, bottom, cap_x1, bottom, INK)


def banner(image: Image.Image, x: int, y: int, width: int, height: int) -> None:
    draw = ImageDraw.Draw(image)
    x1 = x + width - 1
    y1 = y + height - 1
    rect(draw, x, y, x1, y1, DRAPE)
    rect(draw, x, y, x1, y, GOLD_DARK)
    rect(draw, x, y, x, y1, GOLD_DARK)
    rect(draw, x1, y, x1, y1, GOLD_DARK)
    rect(draw, x + 1, y + 1, x1 - 1, y + 1, GOLD_MID)
    for fold in range(x + 5, x1, 8):
        rect(draw, fold, y + 4, fold, y1 - 4, DRAPE_DARK)
        px(draw, fold + 1, y + 6, (58, 40, 74, 255))
    cx = (x + x1) // 2
    cy = y + height // 3
    for dy in range(-4, 5):
        span = 4 - abs(dy)
        rect(draw, cx - span, cy + dy, cx + span, cy + dy, GOLD_MID)
    px(draw, cx, cy, GOLD)
    # Triangular tip.
    for index in range(width // 2):
        rect(draw, x + index, y1 + 1 + index, x1 - index, y1 + 1 + index, DRAPE)
    rect(draw, x + width // 2, y1 + 1 + width // 2, x + width // 2, y1 + 1 + width // 2, GOLD_DARK)


def chain(image: Image.Image, x: int, y0: int, y1: int, lantern: bool) -> None:
    draw = ImageDraw.Draw(image)
    y = y0
    toggle = 0
    while y < y1 - 10:
        if toggle % 2 == 0:
            rect(draw, x - 1, y, x + 1, y, IRON_LIGHT)
            px(draw, x - 1, y + 1, IRON)
            px(draw, x + 1, y + 1, IRON)
        else:
            rect(draw, x, y, x, y + 2, IRON)
        y += 3
        toggle += 1
    if lantern:
        lx = x - 5
        ly = y1 - 10
        rect(draw, lx, ly, lx + 10, ly + 10, IRON)
        rect(draw, lx + 1, ly + 1, lx + 9, ly + 9, (44, 38, 34, 255))
        rect(draw, lx + 4, ly + 2, lx + 6, ly + 8, GOLD_MID)
        px(draw, lx + 5, ly + 4, WHITE_WARM)
        rect(draw, lx + 3, ly - 2, lx + 7, ly - 1, IRON_LIGHT)
        rect(draw, lx + 4, ly + 11, lx + 6, ly + 11, GOLD_DARK)


def niche(image: Image.Image) -> None:
    """Central apse behind the loom: same arch family as the windows."""
    draw = ImageDraw.Draw(image)
    x0, x1 = 600, 840
    y0, y1 = 66, 300
    arch_ring(image, x0, y0, x1, y1, -10, STONE_1)
    arch_ring(image, x0, y0, x1, y1, -9, STONE_3)
    arch_ring(image, x0, y0, x1, y1, -7, STONE_4)
    arch_ring(image, x0, y0, x1, y1, -5, STONE_2)
    arch_ring(image, x0, y0, x1, y1, -3, STONE_1)
    arch_ring(image, x0, y0, x1, y1, -2, STONE_0)
    # Interior: cold indigo depth, not near-black.
    for y, left, right in arch_spans(x0, y0, x1, y1):
        t = (y - y0) / max(1, y1 - y0)
        rect(draw, left, y, right, y, _lerp_color((25, 20, 35, 255), (44, 29, 58, 255), t))
    # 2 px gold inner line follows the arch.  The upper half of the apse stays
    # a deep recess; the tapestry only hangs below it, so the wall does not
    # read as one large flat purple panel.
    for y, left, right in arch_spans(x0 + 2, y0 + 2, x1 - 2, y1):
        px(draw, left, y, GOLD_DARK)
        px(draw, right, y, GOLD_DARK)
    # Soft stepped shadow under the arch crown.
    for step in range(8):
        blend_rect(image, (x0 + 6, y0 + 6 + step, x1 - 6, y0 + 6 + step),
                   (16, 12, 24, 255), 46 - step * 4)
    # Low-contrast loom-star mark in the upper recess, above the machine.
    ecx, ecy = (x0 + x1) // 2, y0 + 62
    for index in range(8):
        angle = index * math.tau / 8.0
        ex = ecx + int(round(math.cos(angle) * 14.0))
        ey = ecy + int(round(math.sin(angle) * 14.0))
        px(draw, ex, ey, (108, 88, 66, 255))
    for y in range(-4, 5):
        span = 4 - abs(y)
        rect(draw, ecx - span, ecy + y, ecx + span, ecy + y, (78, 60, 46, 255))
    # Tapestry: gold hanging rod, dark velvet, vertical folds, fringe.
    dx0, dx1 = x0 + 20, x1 - 20
    dy0 = y0 + 92
    dy1 = y1 - 12
    rect(draw, dx0 - 2, dy0 - 2, dx1 + 2, dy0, GOLD_DARK)
    rect(draw, dx0 - 2, dy0 - 2, dx1 + 2, dy0 - 2, GOLD_MID)
    for cap in (dx0 - 3, dx1 + 3):
        rect(draw, cap, dy0 - 4, cap, dy0 + 1, GOLD_DARK)
        px(draw, cap, dy0 - 5, GOLD_MID)
    rect(draw, dx0, dy0 + 1, dx1, dy1, DRAPE)
    rect(draw, dx0, dy0 + 1, dx0, dy1, GOLD_DARK)
    rect(draw, dx1, dy0 + 1, dx1, dy1, GOLD_DARK)
    for fold in range(dx0 + 10, dx1, 14):
        rect(draw, fold, dy0 + 4, fold, dy1 - 4, DRAPE_DARK)
        rect(draw, fold + 1, dy0 + 5, fold + 1, dy1 - 5, (49, 33, 65, 255))
        px(draw, fold - 1, dy1 - 18, (58, 40, 74, 255))
    # A faint woven emblem at the drape centre (mostly behind the loom).
    ccx, ccy = (dx0 + dx1) // 2, dy0 + 54
    for index in range(4):
        angle = index * math.tau / 4.0 + math.pi / 4.0
        for radius in range(6, 18, 2):
            px(draw, ccx + int(round(math.cos(angle) * radius)),
               ccy + int(round(math.sin(angle) * radius)), (70, 50, 86, 255))
    # Fringe along the drape bottom.
    for fx in range(dx0 + 3, dx1, 7):
        rect(draw, fx, dy1, fx, dy1 + 4, GOLD_DARK)
    # Base shadow where the apse meets the plinth.
    rect(draw, x0 + 2, y1 - 2, x1 - 2, y1, INK)


def plinth(image: Image.Image) -> None:
    draw = ImageDraw.Draw(image)
    rect(draw, 0, 300, 959, 319, STONE_2)
    rect(draw, 0, 300, 959, 300, STONE_5)
    rect(draw, 0, 301, 959, 301, STONE_3)
    rect(draw, 0, 317, 959, 319, STONE_0)
    for bx in range(0, 960, 80):
        rect(draw, bx + 8, 306, bx + 68, 315, STONE_1)
        rect(draw, bx + 8, 306, bx + 68, 306, STONE_0)
        rect(draw, bx + 9, 307, bx + 67, 307, STONE_3)
        rect(draw, bx + 8, 315, bx + 68, 315, SHADOW)


def make_background() -> Image.Image:
    image = Image.new("RGBA", (960, 360), (0, 0, 0, 0))
    ceiling(image)
    brick_wall(image, 0, 55, 959, 299)
    plinth(image)
    # Pilasters first: their cast shadows belong on the wall, under the window
    # frames, never across the glass.
    for px0 in (0, 215, 407, 846, 920):
        pilaster(image, px0, 40)
    # Three identical bays.  Same call, same width, same top; only x changes.
    # Spacing is 188 px so the third frame clears the apse's outer edge.
    for wx in (76, 264, 452):
        window_module(image, wx, 92)
    niche(image)
    banner(image, 224, 54, 26, 96)
    banner(image, 860, 64, 28, 112)
    chain(image, 430, 40, 118, False)
    chain(image, 900, 40, 166, True)
    # One quiet warm floor glow under each brazier, kept below the bowl.
    for cx in (236, 860):
        for radius, alpha in ((22, 10), (14, 14), (8, 18)):
            for y in range(286, 300):
                for x in range(cx - radius, cx + radius + 1):
                    if (x - cx) ** 2 + (y - 286) ** 2 <= radius * radius:
                        blend_rect(image, (x, y, x, y), (240, 154, 74, 255), alpha)
    return image


def make_foreground() -> Image.Image:
    image = Image.new("RGBA", (960, 360), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Narrow side piers + a shallow front lip; the centre stays clear.
    rect(draw, 0, 0, 12, 359, STONE_0)
    rect(draw, 12, 0, 14, 359, STONE_4)
    rect(draw, 14, 0, 16, 359, SHADOW)
    rect(draw, 947, 0, 959, 359, STONE_0)
    rect(draw, 945, 0, 946, 359, SHADOW)
    rect(draw, 944, 0, 944, 359, STONE_4)
    rect(draw, 0, 350, 959, 359, STONE_1)
    rect(draw, 0, 350, 959, 350, GOLD_DARK)
    rect(draw, 0, 351, 959, 352, STONE_4)
    for x in range(10, 950, 48):
        rect(draw, x, 354, x + 22, 355, STONE_2)
        px(draw, x + 4, 357, STONE_3)
    rect(draw, 0, 358, 959, 359, STONE_DARK)
    return image


def make_floor() -> Image.Image:
    image = Image.new("RGBA", (960, 40), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rng = random.Random(27)
    # 8 px top slab, matching the L2 ground's 9-row top band.
    rect(draw, 0, 0, 959, 7, STONE_5)
    rect(draw, 0, 0, 959, 0, STONE_TOP)
    rect(draw, 0, 1, 959, 1, STONE_6)
    for x in range(0, 960, 64):
        rect(draw, x, 0, x, 7, STONE_1)
        px(draw, x + 7, 3, STONE_7)
        if rng.random() < 0.45:
            px(draw, x + 28, 5, STONE_4)
    rect(draw, 0, 7, 959, 7, MORTAR)
    # Joint band: 4 px light, 4 px deep seam.
    rect(draw, 0, 8, 959, 11, STONE_2)
    rect(draw, 0, 12, 959, 15, STONE_0)
    rect(draw, 0, 8, 959, 8, STONE_4)
    rect(draw, 0, 12, 959, 12, STONE_DARK)
    for x in range(0, 960, 64):
        rect(draw, x, 8, x, 11, STONE_1)
        rect(draw, x + 32, 12, x + 32, 15, STONE_1)
    # Recessed iron channel; the vent sprites sit on top of it.
    rect(draw, 0, 16, 959, 23, (24, 21, 26, 255))
    rect(draw, 0, 16, 959, 16, STONE_3)
    rect(draw, 0, 23, 959, 23, STONE_0)
    for x in range(4, 960, 20):
        rect(draw, x, 18, x, 21, IRON_LIGHT)
        if x % 80 == 4:
            px(draw, x, 20, CYAN_DARK)
    # Front face with a single gold line and clean block joints.
    rect(draw, 0, 24, 959, 39, STONE_1)
    rect(draw, 0, 24, 959, 24, STONE_3)
    rect(draw, 0, 25, 959, 25, STONE_4)
    rect(draw, 0, 38, 959, 39, INK)
    for x in range(0, 960, 72):
        rect(draw, x + 8, 28, x + 64, 36, STONE_0)
        rect(draw, x + 8, 28, x + 64, 28, STONE_2)
        rect(draw, x + 8, 36, x + 64, 36, SHADOW)
        px(draw, x + 14, 31, STONE_4)
    # Low purple runner with gold edge; below the player's feet, not a wall.
    rect(draw, 300, 2, 880, 6, DRAPE)
    rect(draw, 300, 2, 880, 2, GOLD_DARK)
    rect(draw, 300, 6, 880, 6, GOLD_DARK)
    for x in range(316, 876, 48):
        rect(draw, x - 2, 4, x + 2, 4, GOLD_DARK)
        px(draw, x, 3, GOLD_MID)
    return image


def make_ui_icons() -> None:
    """Standalone icon references.  HUD code is not changed in this pass."""
    # 20x20 badge: 1 px dark edge, 18x18 plate, 1 px affinity edge.
    for positive, name in ((True, "affinity_sun_20.png"), (False, "affinity_moon_20.png")):
        image = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
        draw = ImageDraw.Draw(image)
        color = GOLD if positive else CYAN
        rect(draw, 0, 0, 19, 19, (1, 3, 4, 255))
        rect(draw, 1, 1, 18, 18, (3, 7, 8, 255))
        draw.rectangle((1, 1, 18, 18), outline=color, width=1)
        center = (10.0, 10.0)
        disc(draw, center[0], center[1], 6, (1, 3, 4, 255))
        disc(draw, center[0], center[1], 5, color)
        if positive:
            for rx, ry in ((9, 2), (9, 16), (2, 9), (16, 9), (4, 4), (14, 4), (4, 14), (14, 14)):
                rect(draw, rx, ry, rx + 1, ry + 1, color)
            rect(draw, 9, 9, 11, 11, WHITE_WARM)
            px(draw, 13, 6, (255, 248, 224, 255))
        else:
            disc(draw, 13.0, 9.0, 4, (3, 7, 8, 255))
            for y in range(-5, 6):
                span = int(round(math.sqrt(max(25.0 - y * y, 0.0))))
                px(draw, int(10 - span), int(10 + y), _lerp_color(color, WHITE_WARM, 0.35))
            for sx, sy in ((14, 3), (15, 13)):
                rect(draw, sx, sy, sx + 2, sy, WHITE_WARM)
                rect(draw, sx + 1, sy - 1, sx + 1, sy + 1, WHITE_WARM)
        image.save(os.path.join(UI_OUT, name))

    # 10x10 heart: 1 px dark outline, 8x8 body, 1 px highlight.
    heart = Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    draw = ImageDraw.Draw(heart)
    rect(draw, 1, 1, 4, 3, (217, 87, 87, 255))
    rect(draw, 5, 1, 8, 3, (217, 87, 87, 255))
    rect(draw, 2, 2, 7, 4, (217, 87, 87, 255))
    rect(draw, 1, 4, 8, 6, (217, 87, 87, 255))
    rect(draw, 2, 6, 7, 7, (217, 87, 87, 255))
    rect(draw, 3, 7, 6, 8, (217, 87, 87, 255))
    rect(draw, 4, 8, 5, 9, (217, 87, 87, 255))
    # Dark 1 px edge around the silhouette.
    for x in range(10):
        for y in range(10):
            if heart.getpixel((x, y))[3] == 0:
                continue
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < 10 and 0 <= ny < 10 and heart.getpixel((nx, ny))[3] == 0:
                    heart.putpixel((nx, ny), (20, 16, 18, 255))
    px(draw, 3, 2, (255, 123, 123, 255))
    px(draw, 2, 3, (255, 123, 123, 255))
    heart.save(os.path.join(UI_OUT, "heart_10.png"))


def main() -> None:
    global UI_OUT
    os.makedirs(OUT, exist_ok=True)
    UI_OUT = os.path.abspath(os.path.join(DLC, "..", "..", "assets", "ui", "icons"))
    os.makedirs(UI_OUT, exist_ok=True)
    make_background().save(os.path.join(OUT, "city_back_960x360.png"))
    make_foreground().save(os.path.join(OUT, "city_fore_960x360.png"))
    make_floor().save(os.path.join(OUT, "city_floor_960x40.png"))
    make_ui_icons()
    print("CITY_V2_DONE", OUT)
    print("UI_ICONS_DONE", UI_OUT)


if __name__ == "__main__":
    main()
