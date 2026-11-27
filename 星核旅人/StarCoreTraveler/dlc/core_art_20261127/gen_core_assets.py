"""Rebuild the star-core and star-core-bay pixel art (2026-11-27).

Scope: only the two approved asset families, at their existing sizes:
  assets/star_core/*.png          16x16 still, 192x16 (12 frames)
  assets/star_core_bay/*.png      32x32 base / glass / empty preview

The generator is deterministic Pillow pixel art.  No third-party image is
read or sampled; the external references are study-only and live next to
this script under references/ (.gdignore'd).  Originals are preserved in
original/ and were copied before the first write.

Run with:
  D:/minic/envs/2024212971/python.exe dlc/core_art_20261127/gen_core_assets.py
"""

from __future__ import annotations

import math
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORE_DIR = os.path.join(ROOT, "assets", "star_core")
BAY_DIR = os.path.join(ROOT, "assets", "star_core_bay")
ORIGINAL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "original")

CORE_SIZE = 16
FRAME_COUNT = 12

# Approved palette anchors.  Gold #f4cd63 and cyan #5fe1e6 are the project's
# star-core accents; the locked purple is the existing third state.  Stone is
# the L2/L3 cold-grey family.  No new accent hue is introduced.
GOLD = (244, 205, 99, 255)

PALETTES = {
    "positive": {
        "outline": (42, 26, 12, 255),
        "deep": (96, 56, 6, 255),
        "dark": (158, 94, 10, 255),
        "base": (226, 158, 26, 255),
        "mid": (240, 183, 44, 255),
        "light": (255, 229, 140, 255),
        "hi": (255, 246, 205, 255),
        "core": (255, 250, 220, 255),
        "ring_dim": (146, 102, 34, 255),
        "ring_mid": (205, 156, 62, 255),
        "ring_hi": (255, 226, 144, 255),
        "dust": (255, 239, 181, 255),
    },
    "negative": {
        "outline": (4, 28, 34, 255),
        "deep": (4, 74, 86, 255),
        "dark": (8, 116, 132, 255),
        "base": (22, 170, 186, 255),
        "mid": (48, 207, 220, 255),
        "light": (126, 239, 243, 255),
        "hi": (218, 255, 255, 255),
        "core": (241, 255, 255, 255),
        "ring_dim": (146, 102, 34, 255),
        "ring_mid": (205, 156, 62, 255),
        "ring_hi": (255, 226, 144, 255),
        "dust": (169, 247, 250, 255),
    },
    "locked": {
        "outline": (28, 10, 40, 255),
        "deep": (64, 18, 88, 255),
        "dark": (110, 34, 150, 255),
        "base": (156, 62, 198, 255),
        "mid": (196, 108, 228, 255),
        "light": (242, 174, 252, 255),
        "hi": (255, 232, 255, 255),
        "core": (255, 241, 255, 255),
        "ring_dim": (146, 102, 34, 255),
        "ring_mid": (205, 156, 62, 255),
        "ring_hi": (255, 226, 144, 255),
        "dust": (238, 188, 255, 255),
    },
}

# Stone / brass bay palette.  Stone values sit inside the L2/L3 family
# (76..172 grey-violet) and the gold stays the approved #f4cd63 family.
STONE_HI = (238, 243, 233, 255)
STONE_LIGHT = (213, 223, 218, 255)
STONE_MID = (176, 191, 189, 255)
STONE = (143, 160, 160, 255)
STONE_DARK = (103, 122, 124, 255)
STONE_DEEP = (68, 84, 87, 255)
SEAM = (46, 61, 64, 255)
STEEL_DARK = (37, 52, 55, 255)
GOLD_DIM = (146, 102, 34, 255)
GOLD_MID = (196, 150, 58, 255)
GOLD_HI = (255, 226, 144, 255)
SOCKET = (25, 37, 40, 255)


def blank(width: int, height: int) -> Image.Image:
    return Image.new("RGBA", (width, height), (0, 0, 0, 0))


def put(px, x: int, y: int, color) -> None:
    if x < 0 or y < 0:
        return
    try:
        px[x, y] = color
    except IndexError:
        pass


def rect(px, x0: int, y0: int, x1: int, y1: int, color) -> None:
    """Inclusive pixel rectangle."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(px, x, y, color)


def mix(a, b, t: float):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


# ---------------------------------------------------------------------------
# Star core: 12-frame rotating cut gem + fixed outer gold ring + inner light.
# ---------------------------------------------------------------------------


def core_frame(state: str, frame: int) -> Image.Image:
    pal = PALETTES[state]
    image = blank(CORE_SIZE, CORE_SIZE)
    px = image.load()

    # 0 = full face, 6 = edge-on sliver.  Frames 0-3 stay broad so the L1
    # handoff (which only plays 0-3) always presents a complete orb.
    phase = math.cos(math.pi * frame / FRAME_COUNT)
    width = 1.0 + 4.2 * abs(phase)  # half-width, px
    height = 5.0

    # Breathing is a brightness cycle, never a position offset.  The trough is
    # deliberately readable at 12 fps: the table and ring both dim together.
    pulse = 0.5 + 0.5 * math.cos(math.tau * (frame - 2.0) / FRAME_COUNT)
    body_dim = 0.15 * (1.0 - pulse)

    # Build the gem body.  A superellipse gives a cut, slightly squared gem
    # instead of a soft coin edge.
    body = set()
    for y in range(CORE_SIZE):
        for x in range(CORE_SIZE):
            dx = (x + 0.5) - 7.5
            dy = (y + 0.5) - 7.5
            if abs(dx) > width or abs(dy) > height:
                continue
            nx = dx / max(width, 0.001)
            ny = dy / height
            if abs(nx) ** 2.8 + abs(ny) ** 3.0 <= 1.0:
                body.add((x, y))

    for x, y in body:
        dx = (x + 0.5) - 7.5
        dy = (y + 0.5) - 7.5
        nx = dx / max(width, 0.001)
        ny = dy / height
        # Three large cut planes plus a darker pavilion.  Keep the values
        # clearly separated so the facets survive at native 16x16.
        if ny < -0.45 and nx < 0.25:
            color = pal["hi"]
        elif nx < -0.35:
            color = pal["light"]
        elif nx > 0.30:
            color = pal["dark"]
        elif ny > 0.50:
            color = pal["dark"]
        else:
            color = pal["base"]
        # Lower-left table falls one step darker.
        if nx < -0.15 and ny > 0.22:
            color = pal["mid"]
        # Bright top-left bevel.
        if ny < 0.05 and nx < -0.55:
            color = pal["hi"]
        # Girdle line: a hard 1 px cut across the table.
        if abs(ny - 0.08) < 0.075 and abs(nx) > 0.12:
            color = pal["deep"]
        if ny > 0.78:
            color = pal["deep"]
        if body_dim > 0.0:
            color = mix(color, pal["deep"], body_dim)
        px[x, y] = color

    # 1 px edge: lit gold on the top-left rim, warm dark on the bottom-right
    # rim.  This avoids a heavy brown outline around the whole gem.
    edge = set()
    for x, y in body:
        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + ox, y + oy)
            if q not in body and 0 <= q[0] < CORE_SIZE and 0 <= q[1] < CORE_SIZE:
                edge.add(q)
    for x, y in edge:
        dx = (x + 0.5) - 7.5
        dy = (y + 0.5) - 7.5
        px[x, y] = pal["hi"] if dx + dy < 0 else pal["outline"]

    # Inner light: a white-hot 2x2 core with a tiny four-point halo.  The halo
    # is deliberately small so the three cut faces stay readable at 16x16.
    halo = mix(pal["light"], pal["core"], 0.30 + 0.38 * pulse)
    for x, y in ((6, 7), (9, 7), (7, 6), (8, 9)):
        if (x, y) in body:
            px[x, y] = halo
    for x, y in ((7, 7), (8, 7), (7, 8), (8, 8)):
        px[x, y] = pal["core"]
    for x in (7, 8):
        if (x, 5) in body:
            px[x, 5] = pal["hi"]
        if (x, 10) in body:
            px[x, 10] = pal["light"]

    # Fixed thin gold orbit ring, radius 6.9.  One continuous pixel circle with
    # two brighter arcs; it never translates, so the spin stays inside it.
    ring_r = 6.9
    steps = 96
    ring_points = []
    for i in range(steps):
        angle = math.tau * i / steps
        x = int(round(7.5 + math.cos(angle) * ring_r - 0.5))
        y = int(round(7.5 + math.sin(angle) * ring_r - 0.5))
        if (x, y) not in ring_points:
            ring_points.append((x, y))
    for x, y in ring_points:
        angle = math.atan2(y - 7.5, x - 7.5)
        bead = max(0.0, math.cos(angle + 2.2)) ** 3
        bead += 0.35 * max(0.0, math.cos(angle - 1.2)) ** 4
        ring_color = mix(
            pal["ring_dim"], pal["ring_hi"],
            0.04 + 0.58 * min(1.0, bead) * (0.30 + 0.70 * pulse),
        )
        px[x, y] = ring_color

    # Two tiny orbiting specks, one pixel each.  They rotate while the gem
    # stays centred, so the loop breathes instead of translating.
    for index, base_angle in enumerate((-2.0, 1.15)):
        angle = base_angle + math.tau * frame / (FRAME_COUNT * 2.0)
        radius = 7.7
        x = int(round(7.5 + math.cos(angle) * radius - 0.5))
        y = int(round(7.5 + math.sin(angle) * radius - 0.5))
        if (x, y) not in body and 0 <= x < CORE_SIZE and 0 <= y < CORE_SIZE:
            px[x, y] = pal["dust"] if index == 0 else mix(pal["dust"], pal["ring_dim"], 0.40)

    return image


def build_core_sheet(state: str) -> Image.Image:
    sheet = blank(CORE_SIZE * FRAME_COUNT, CORE_SIZE)
    for frame in range(FRAME_COUNT):
        sheet.paste(core_frame(state, frame), (frame * CORE_SIZE, 0))
    return sheet


# ---------------------------------------------------------------------------
# Star-core bay: stone plinth + brass socket ring, and a glass dome with a
# brass frame, diagonal reflection and an inner cold vignette.
# ---------------------------------------------------------------------------


def build_base() -> Image.Image:
    image = blank(32, 32)
    px = image.load()

    # Top slab (pedestal top stays at image y=24 = local +8, as the shared
    # StarCoreBayVisual expects).  The shallow gold socket extends 2 px above
    # the slab so an empty bay still has a clear "put the core here" ring.
    rect(px, 3, 24, 28, 24, STONE_HI)
    put(px, 2, 24, STONE_LIGHT)
    put(px, 29, 24, STONE_LIGHT)
    rect(px, 2, 25, 29, 25, STONE_LIGHT)
    rect(px, 2, 25, 3, 25, STONE_HI)
    rect(px, 2, 26, 29, 26, STONE_MID)
    rect(px, 27, 26, 29, 26, STONE)
    # Dark seam under the cap.
    rect(px, 4, 27, 27, 27, SEAM)
    put(px, 3, 27, STONE_DARK)
    put(px, 28, 27, STONE_DARK)

    # Waist and flared foot: chamfered silhouette, top-left lit.
    rect(px, 5, 28, 26, 28, STONE)
    rect(px, 5, 28, 6, 28, STONE_LIGHT)
    rect(px, 25, 28, 26, 28, STONE_DARK)
    rect(px, 5, 29, 26, 29, STONE_DARK)
    rect(px, 5, 29, 6, 29, STONE)
    rect(px, 25, 29, 26, 29, STONE_DEEP)
    rect(px, 3, 30, 28, 30, STONE_LIGHT)
    rect(px, 3, 30, 4, 30, STONE_HI)
    rect(px, 27, 30, 28, 30, STONE_MID)
    rect(px, 3, 31, 28, 31, STONE_DARK)
    rect(px, 4, 31, 27, 31, STONE_DEEP)
    put(px, 3, 31, STEEL_DARK)
    put(px, 28, 31, STEEL_DARK)

    # Block joints: one vertical dark seam each side, kept away from the
    # code-drawn 4x3 lock mark at image (20..23, 27..29).
    for y in range(27, 31):
        put(px, 8, y, SEAM if y != 30 else STONE_DARK)
        put(px, 23, y, SEAM if y != 30 else STONE_DARK)
    # A 1 px brass inlay at each side of the waist: the metal-frame hint.
    for y in range(27, 30):
        px[6, y] = GOLD_DIM
        px[25, y] = GOLD_DIM
    put(px, 6, 28, GOLD_HI)
    put(px, 25, 29, GOLD_HI)
    # One-pixel brass caps on the top slab ends.
    put(px, 2, 25, GOLD_MID)
    put(px, 29, 25, GOLD_MID)

    # Shallow oval socket: a dim gold rim and dark recess.  It is behind the
    # core (z=1) and below the glass (z=3); a seated core covers the centre,
    # while the empty bay keeps a clear gold-ring hint.
    rect(px, 13, 23, 18, 23, GOLD_DIM)
    put(px, 12, 23, SOCKET)
    put(px, 19, 23, SOCKET)
    rect(px, 11, 24, 11, 25, GOLD_MID)
    rect(px, 20, 24, 20, 25, GOLD_MID)
    rect(px, 12, 24, 19, 25, SOCKET)
    rect(px, 12, 26, 19, 26, GOLD_DIM)
    put(px, 11, 26, SOCKET)
    put(px, 20, 26, SOCKET)

    return image


def build_glass() -> Image.Image:
    """A clean 32x32 bell-jar dome with a 1 px brass frame.

    The silhouette is rebuilt from the same 32x32 envelope instead of tracing
    the previous PNG: a smooth dome is easier to keep clean at 1:1.  The 16x16
    core window (image x=8..23, y=8..23) stays fully transparent, preserving
    the shared StarCoreBayVisual contract.  All colours are authored here.
    """
    image = blank(32, 32)
    px = image.load()

    def dome_span(y: int) -> tuple[int, int]:
        if y >= 24:
            return 1, 30
        dy = (24.0 - float(y)) / 23.0
        half = max(2.0, 13.8 * math.sqrt(max(0.0, 1.0 - dy * dy)))
        return int(round(15.5 - half)), int(round(15.5 + half))

    # Glass interior and 1 px brass rim, row by row.  The fill is opaque
    # enough to read as glass at 1:1 but stays below the core window.
    for y in range(1, 25):
        left, right = dome_span(y)
        for x in range(left, right + 1):
            if 8 <= x <= 23 and 8 <= y <= 23:
                continue
            border = x == left or x == right or y == 1 or y == 24
            if border:
                if y < 10 or (x <= left + 1 and y < 18):
                    px[x, y] = (235, 209, 137, 240)
                elif y > 19 or x >= right - 1:
                    px[x, y] = (74, 52, 24, 245)
                else:
                    px[x, y] = (146, 102, 34, 240)
            else:
                # Cold cyan glass, brighter near the top shoulder.
                depth = min(x - left, right - x, 24 - y)
                alpha = 44 if depth <= 2 else 30
                if y <= 8:
                    alpha += 8
                px[x, y] = (108, 199, 211, alpha)

    # Inner pale-cyan lip just inside the frame.
    for y in range(2, 24):
        left, right = dome_span(y)
        for x in (left + 1, right - 1):
            if 8 <= x <= 23 and 8 <= y <= 23:
                continue
            if px[x, y][3] > 0 and x not in (left, right):
                px[x, y] = (165, 235, 241, 118)
    for x in range(14, 18):
        if px[x, 2][3] > 0:
            px[x, 2] = (165, 235, 241, 110)

    # Inner cold vignette at the lower corners, outside the core window.
    for y in range(17, 24):
        for x in list(range(2, 8)) + list(range(24, 30)):
            if px[x, y][3] > 0:
                px[x, y] = (42, 88, 96, 78 if y < 20 else 112)
    for x, y in ((3, 5), (4, 5), (3, 6), (28, 5), (27, 5), (28, 6)):
        if px[x, y][3] > 0:
            px[x, y] = (42, 88, 96, 68)

    # Diagonal reflection on the left shoulder, kept outside the core window.
    # A two-pixel band survives the 1:1 downscale better than a single line.
    streak = [(5, 9), (6, 9), (5, 10), (6, 10), (6, 11), (7, 11),
              (6, 12), (7, 12), (7, 13), (7, 14), (7, 15), (7, 16),
              (6, 17), (6, 18), (5, 18)]
    for x, y in streak:
        if px[x, y][3] > 0 and not (8 <= x <= 23 and 8 <= y <= 23):
            px[x, y] = (225, 253, 255, 205 if y < 14 else 150)
    # A long diagonal glint across the upper-left crown, above the core window.
    crown_glint = [(8, 3), (9, 3), (9, 4), (10, 4), (10, 5), (11, 5),
                   (11, 6), (12, 6), (12, 7)]
    for x, y in crown_glint:
        if px[x, y][3] > 0 and y < 8:
            px[x, y] = (235, 255, 255, 205)
    # A dim reflection on the right shoulder.
    for x, y in ((25, 10), (25, 11), (26, 11), (26, 12), (26, 13)):
        if px[x, y][3] > 0 and not (8 <= x <= 23 and 8 <= y <= 23):
            px[x, y] = (185, 243, 247, 58)

    # Brass sill at the base.  Row 24 is below the core window, so the core
    # still shows through the transparent 16x16 window above.
    for x in range(3, 29):
        px[x, 24] = GOLD_DIM
    for x in range(4, 28):
        px[x, 25] = (74, 52, 24, 235)
    for x in (9, 10, 21, 22):
        px[x, 24] = GOLD_MID
    put(px, 9, 24, GOLD_HI)
    # Small central latch plate, also below the core window.
    rect(px, 14, 24, 17, 24, GOLD_MID)
    rect(px, 14, 24, 15, 24, GOLD_HI)
    put(px, 16, 24, GOLD_HI)

    return image


def build_empty_preview(base: Image.Image) -> Image.Image:
    # Empty = plinth and socket only.  The shared bay hides the glass when
    # open, so this preview matches that state.
    preview = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    preview.alpha_composite(base)
    return preview


def main() -> None:
    os.makedirs(CORE_DIR, exist_ok=True)
    os.makedirs(BAY_DIR, exist_ok=True)

    for state in ("positive", "negative", "locked"):
        sheet = build_core_sheet(state)
        path = os.path.join(CORE_DIR, f"star_core_{state}_12f.png")
        sheet.save(path, optimize=True)
        # The static fallback is frame 0 of the same sheet, not a recolour.
        sheet.crop((0, 0, 16, 16)).save(
            os.path.join(CORE_DIR, f"star_core_{state}.png"), optimize=True
        )
        print("WROTE", path, sheet.size)

    base = build_base()
    base.save(os.path.join(BAY_DIR, "star_core_bay_base.png"), optimize=True)
    print("WROTE base", base.size)
    glass = build_glass()
    glass.save(os.path.join(BAY_DIR, "star_core_bay_glass.png"), optimize=True)
    print("WROTE glass", glass.size)
    empty = build_empty_preview(base)
    empty.save(os.path.join(BAY_DIR, "star_core_bay_empty.png"), optimize=True)
    print("WROTE empty preview", empty.size)


if __name__ == "__main__":
    main()
