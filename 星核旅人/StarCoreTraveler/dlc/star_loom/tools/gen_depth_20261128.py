"""DLC3 star-loom indoor depth pass (2026-11-28).

Adds a *derived* deeper loom hall behind the approved city wall.  The approved
`city_v2/city_back_960x360.png` is never opened or overwritten.  The far hall is
a separate 1280x360 layer (enough width for a 0.65 parallax across the 960 px
chapter) and is composited only into the central loom apse and the right-hand
mirror-door recess.  The three cloud-sea windows stay untouched.

Files written
  loom_hall_deep_1280x360.png        far loom hall; parallax 0.65
  loom_niche_door_mask_960x360.png   alpha mask of the central apse + door recess

The approved `city_back_960x360.png` is used unchanged in the scene.  A masked
overlay draws the far hall only through the apse/door mask, so the three window
panes, frames, leaded bars, cloud-sea accents and the whole wall stay exactly
as approved.  The overlay and the mirror door's dark recess are held at zero
strength while the opening film runs; they fade in after control returns.

Original procedural pixel art.  No third-party image, palette or sprite is
read; the hall reuses the project's blue-grey stone/thread families.

Run:
    D:/minic/envs/2024212971/python.exe dlc/star_loom/tools/gen_depth_20261128.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DLC = os.path.dirname(HERE)
OUT = os.path.join(DLC, "assets", "city_v2")

W = 1280
H = 360

# Distant loom hall: a cold blue-grey interior, clearly darker than the window
# sky, but never near-black.  Values sit around 40-60 so the leaded bars and
# accents still read as glass.
HALL_TOP = (26, 34, 42, 255)
HALL_BOTTOM = (20, 26, 34, 255)
HALL_0 = (30, 39, 47, 255)
HALL_1 = (34, 43, 51, 255)
HALL_2 = (38, 48, 56, 255)
HALL_3 = (43, 53, 61, 255)
HALL_4 = (48, 58, 66, 255)
HALL_HI = (60, 72, 82, 255)
HALL_DARK = (18, 24, 31, 255)
HALL_INK = (14, 19, 25, 255)

BEAM_0 = (31, 39, 46, 255)
BEAM_1 = (37, 46, 54, 255)
BEAM_2 = (44, 54, 62, 255)
BEAM_HI = (58, 70, 80, 255)

THREAD_COOL = (56, 66, 72, 255)
THREAD_WARM = (64, 58, 46, 255)
THREAD_DIM = (43, 50, 54, 255)
THREAD_HI = (78, 82, 78, 255)
LAMP = (104, 78, 48, 255)
LAMP_DIM = (62, 50, 36, 255)


def rect(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, color) -> None:
    if x1 < x0 or y1 < y0:
        return
    draw.rectangle((x0, y0, x1, y1), fill=color)


def px(draw: ImageDraw.ImageDraw, x: int, y: int, color) -> None:
    if 0 <= x < draw.im.size[0] and 0 <= y < draw.im.size[1]:
        draw.point((x, y), fill=color)


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


def far_column(img: Image.Image, x: int, width: int = 22) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x, 34, x + width - 1, 320, HALL_2)
    # A slight broad face and two edge lights; no bright vertical stripes.
    rect(draw, x + 3, 40, x + width - 4, 314, HALL_1)
    rect(draw, x, 34, x, 320, HALL_HI)
    rect(draw, x + 1, 34, x + 1, 320, HALL_3)
    rect(draw, x + width - 2, 34, x + width - 2, 320, HALL_DARK)
    rect(draw, x + width - 1, 34, x + width - 1, 320, HALL_INK)
    # Capital and base: two quiet horizontal steps.
    rect(draw, x - 3, 30, x + width + 2, 35, HALL_3)
    rect(draw, x - 3, 30, x + width + 2, 30, HALL_HI)
    rect(draw, x - 2, 35, x + width + 1, 37, HALL_1)
    rect(draw, x - 3, 312, x + width + 2, 320, HALL_3)
    rect(draw, x - 3, 312, x + width + 2, 312, HALL_4)
    rect(draw, x - 2, 318, x + width + 1, 320, HALL_DARK)


def far_beam_h(img: Image.Image, y: int, x0: int = 0, x1: int = W - 1) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x0, y, x1, y + 9, BEAM_1)
    rect(draw, x0, y, x1, y, BEAM_HI)
    rect(draw, x0, y + 1, x1, y + 1, BEAM_2)
    rect(draw, x0, y + 9, x1, y + 9, HALL_INK)
    # Iron straps at a sparse rhythm.
    for bx in range(x0 + 36, x1, 96):
        rect(draw, bx, y - 1, bx + 3, y + 10, BEAM_0)
        px(draw, bx, y - 1, HALL_HI)
        px(draw, bx + 2, y + 8, HALL_INK)


def far_arch(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    draw = ImageDraw.Draw(img)
    for y, left, right in arch_spans(x0 - 7, y0 - 7, x1 + 7, y1):
        rect(draw, left, y, right, y, HALL_0)
    for y, left, right in arch_spans(x0 - 6, y0 - 6, x1 + 6, y1):
        rect(draw, left, y, right, y, HALL_3)
    for y, left, right in arch_spans(x0, y0, x1, y1):
        t = (y - y0) / float(max(1, y1 - y0))
        rect(draw, left, y, right, y, (
            int(round(21 + 5 * t)),
            int(round(27 + 5 * t)),
            int(round(33 + 5 * t)),
            255,
        ))
    for y, left, right in arch_spans(x0, y0, x1, y1):
        px(draw, left, y, HALL_HI)
        px(draw, right, y, HALL_INK)


def thread(img: Image.Image, x: int, y0: int, y1: int, warm: bool = False,
           sag: int = 0) -> None:
    draw = ImageDraw.Draw(img)
    color = THREAD_WARM if warm else THREAD_COOL
    span = max(1, y1 - y0)
    for y in range(y0, y1 + 1):
        offset = 0
        if sag > 0 and y > y0 + span // 2:
            offset = int(round(sag * (y - y0 - span / 2.0) / (span / 2.0)))
        xx = x + offset
        px(draw, xx, y, color)
        if y % 7 == 0:
            px(draw, xx, y, THREAD_HI if y % 14 == 0 else THREAD_DIM)
    # A small loom weight at the bottom.
    rect(draw, x - 1 + sag, y1 + 1, x + 1 + sag, y1 + 3, BEAM_0)
    px(draw, x - 1 + sag, y1 + 3, BEAM_HI)
    px(draw, x + 1 + sag, y1 + 3, HALL_INK)


def heddle_bar(img: Image.Image, x0: int, x1: int, y: int) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x0, y, x1, y + 3, BEAM_0)
    rect(draw, x0, y, x1, y, BEAM_2)
    for x in range(x0 + 4, x1, 12):
        rect(draw, x, y + 3, x, y + 7, BEAM_1)
        px(draw, x, y + 3, BEAM_HI)
        px(draw, x, y + 7, HALL_INK)


def far_gear(img: Image.Image, cx: int, cy: int, radius: int) -> None:
    draw = ImageDraw.Draw(img)
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                 fill=HALL_0)
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                 outline=HALL_4, width=1)
    for index in range(12):
        angle = math.tau * index / 12.0
        tx = cx + int(round(math.cos(angle) * (radius - 1)))
        ty = cy + int(round(math.sin(angle) * (radius - 1)))
        rect(draw, tx - 2, ty - 2, tx + 2, ty + 2, HALL_0)
        px(draw, tx - 2, ty - 2, HALL_3)
    draw.ellipse((cx - radius // 3, cy - radius // 3,
                  cx + radius // 3, cy + radius // 3), fill=HALL_INK)
    draw.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=HALL_2)


def make_hall() -> Image.Image:
    img = Image.new("RGBA", (W, H), HALL_TOP)
    draw = ImageDraw.Draw(img)
    # Vertical ambient gradient; 1 px steps, no dither noise.
    for y in range(H):
        t = y / float(H - 1)
        color = (
            int(round(HALL_TOP[0] + (HALL_BOTTOM[0] - HALL_TOP[0]) * t)),
            int(round(HALL_TOP[1] + (HALL_BOTTOM[1] - HALL_TOP[1]) * t)),
            int(round(HALL_TOP[2] + (HALL_BOTTOM[2] - HALL_TOP[2]) * t)),
            255,
        )
        rect(draw, 0, y, W - 1, y, color)
    # Far wall brick, 32x16, barely visible through the window.
    for y in range(48, 330):
        row = (y - 48) // 16
        offset = 0 if row % 2 == 0 else 16
        for x in range(W):
            if (y - 48) % 16 == 0:
                tone = HALL_2
            elif (y - 48) % 16 == 15:
                tone = HALL_DARK
            elif (x + offset) % 32 == 0:
                tone = HALL_DARK
            else:
                tone = HALL_0 if ((row * 3 + (x + offset) // 32) % 4) else HALL_1
            img.putpixel((x, y), tone)
    # Distant lower arcade: small, dark, behind the columns.
    for index in range(12):
        x0 = 16 + index * 110
        far_arch(img, x0, 238, x0 + 72, 320)
    # Columns every 150 px; the 1280-wide layer gives a stable rhythm under
    # the 0.65 parallax.
    for index in range(9):
        far_column(img, 42 + index * 150, 22)
    # Two high beams and one low beam; the window transoms sit between them.
    far_beam_h(img, 104)
    far_beam_h(img, 178)
    far_beam_h(img, 292)
    # Loom heddle bars and gears: low contrast, read as machinery only after
    # the eye has settled.
    for x0 in (92, 452, 812, 1172):
        heddle_bar(img, x0, x0 + 168, 150)
        heddle_bar(img, x0, x0 + 156, 214)
    far_gear(img, 290, 254, 28)
    far_gear(img, 700, 250, 34)
    far_gear(img, 1020, 256, 24)
    # Hanging threads.  These are the vertical "warp" of the hall: 1 px,
    # mostly cool, a few warm, with tiny weights at the bottom.
    for index in range(64):
        x = 8 + index * 20 + ((index * 7) % 9)
        y0 = 186 if index % 5 else 116
        y1 = 270 + ((index * 13) % 16)
        thread(img, x, y0, y1, warm=(index % 7 == 0), sag=2 if index % 4 == 0 else 0)
    # A few very short broken fibers near the top, not a curtain.
    for index in range(18):
        x = 24 + index * 70 + ((index * 11) % 13)
        thread(img, x, 118 + (index % 3) * 7, 146 + (index % 4) * 9,
               warm=(index % 3 == 0))
    # Dim lamps at the far wall, 1-2 px, no bloom.
    for cx in (176, 476, 776, 1076):
        px(draw, cx, 136, LAMP)
        px(draw, cx - 1, 136, LAMP_DIM)
        px(draw, cx + 1, 136, LAMP_DIM)
        rect(draw, cx - 3, 139, cx + 3, 139, HALL_DARK)
    # A low balustrade and a dark floor band; the window sill hides the seam.
    rect(draw, 0, 306, W - 1, 311, HALL_3)
    rect(draw, 0, 306, W - 1, 306, HALL_4)
    rect(draw, 0, 311, W - 1, 311, HALL_INK)
    for bx in range(10, W, 46):
        rect(draw, bx, 308, bx + 24, 310, HALL_1)
        px(draw, bx, 308, HALL_2)
    rect(draw, 0, 312, W - 1, H - 1, HALL_INK)
    return img


def make_niche_door_mask() -> Image.Image:
    """White only in the central loom apse and the right mirror-door recess.

    The three 126x204 window panes (x=76/264/452) are deliberately absent, so
    the approved same-pattern cloud-sea windows receive no dark layer at all.
    """
    img = Image.new("RGBA", (960, 360), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Central apse interior: inside the gold inner line and stone rings.
    for y, left, right in arch_spans(604, 70, 836, 298):
        rect(draw, left, y, right, y, (255, 255, 255, 255))
    # Right-hand mirror-door recess: the 36x96 inner opening of
    # MirrorRiftGate at world x=420, y=320 (local -18..18, -96..0).
    rect(draw, 402, 224, 437, 319, (255, 255, 255, 255))
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    hall = make_hall()
    hall.save(os.path.join(OUT, "loom_hall_deep_1280x360.png"))
    mask = make_niche_door_mask()
    mask.save(os.path.join(OUT, "loom_niche_door_mask_960x360.png"))
    print("WROTE loom_hall_deep_1280x360.png", hall.size)
    print("WROTE loom_niche_door_mask_960x360.png", mask.size)
    print("LOOM_DEPTH_DONE", OUT)


if __name__ == "__main__":
    main()
