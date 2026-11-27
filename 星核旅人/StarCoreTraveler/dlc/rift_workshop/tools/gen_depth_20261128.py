"""DLC2 rift-workshop indoor depth pass (2026-11-28).

Adds a *derived* deeper workshop hall, a throat mask and a small furnace-smoke
texture for the atmosphere layer.  The approved `interior_back_1880x360.png` is
never read, opened or overwritten: the scene keeps it and composites the far
hall through the mask.

Files written
  interior_deep_1880x360.png       far workshop hall; parallax 0.65; ~30% darker
  interior_depth_mask_1880x360.png alpha mask of the two arch throats only
  rift_furnace_smoke_96x48.png     soft smoke mask for the world-front layer

The approved `interior_back_1880x360.png` is used unchanged in the scene.  A
masked overlay inside the Background CanvasLayer draws the far hall only in the
entry and bridge arch throats; the stone frame, recess gap, inner lip, mirror
hall and furnace breast stay exactly as approved.  The overlay is held at zero
strength during the opening film and fades in after control returns.

Original procedural pixel art.  The deeper hall uses the same grey-mauve stone,
timber and iron family as the approved interior, pressed down by roughly 30% in
value so it reads as distance instead of a second foreground wall.

Run:
    D:/minic/envs/2024212971/python.exe dlc/rift_workshop/tools/gen_depth_20261128.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
DLC = os.path.dirname(HERE)
OUT = os.path.join(DLC, "assets", "interior")

W = 1880
H = 360

# Far-hall palette: the approved stone family multiplied by ~0.70.  The
# median luminance of the visible band stays inside the requested 25-35%
# darkening band (about 33-36 against the approved wall's 47-49).
DEEP_SKY = (34, 31, 34, 255)
DEEP_0 = (39, 35, 37, 255)
DEEP_1 = (42, 38, 40, 255)
DEEP_2 = (45, 41, 43, 255)
DEEP_3 = (48, 43, 45, 255)
DEEP_4 = (52, 47, 48, 255)
DEEP_5 = (56, 50, 50, 255)
DEEP_HI = (64, 56, 54, 255)
DEEP_MORTAR = (31, 28, 30, 255)
DEEP_INK = (25, 23, 25, 255)

WOOD_0 = (37, 29, 25, 255)
WOOD_1 = (43, 34, 29, 255)
WOOD_2 = (49, 39, 33, 255)
IRON_0 = (33, 31, 30, 255)
IRON_1 = (39, 36, 34, 255)
IRON_2 = (45, 41, 37, 255)
IRON_HI = (56, 49, 41, 255)

FIRE_DARK = (70, 40, 22, 255)
FIRE_MID = (94, 52, 26, 255)
FIRE_LIGHT = (124, 70, 34, 255)


def rect(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, color) -> None:
    if x1 < x0 or y1 < y0:
        return
    draw.rectangle((x0, y0, x1, y1), fill=color)


def px(draw: ImageDraw.ImageDraw, x: int, y: int, color) -> None:
    if 0 <= x < draw.im.size[0] and 0 <= y < draw.im.size[1]:
        draw.point((x, y), fill=color)


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


def deep_brick(img: Image.Image, x0: int, y0: int, x1: int, y1: int,
               seed: int = 28112026) -> None:
    """Large, quiet 32x16 coursing; one step darker than the approved wall."""
    draw = ImageDraw.Draw(img)
    tones = (DEEP_0, DEEP_1, DEEP_1, DEEP_2, DEEP_2, DEEP_3)
    for y in range(y0, y1 + 1):
        row = (y - y0) // 16
        offset = 0 if row % 2 == 0 else 16
        for x in range(x0, x1 + 1):
            if (y - y0) % 16 == 0:
                tone = DEEP_4
            elif (y - y0) % 16 == 15:
                tone = DEEP_MORTAR
            elif (x - x0 + offset) % 32 == 0:
                tone = DEEP_MORTAR
            else:
                # Deterministic low-frequency variation, no random noise.
                tone = tones[((row * 7 + (x - x0 + offset) // 32 * 5) % len(tones))]
            img.putpixel((x, y), tone)
    # Very sparse 1 px wear marks, darker only.
    for y in range(y0 + 5, y1 - 4, 23):
        x = x0 + 11 + ((y * 13) % max(1, x1 - x0 - 22))
        if x0 <= x < x1:
            px(draw, x, y, DEEP_MORTAR)
    if seed:
        pass


def deep_arch(img: Image.Image, x0: int, y0: int, x1: int, y1: int) -> None:
    """A distant arch bay: wide stone rim, near-black throat, 1 px lip."""
    draw = ImageDraw.Draw(img)
    # Outer rim first, then a darker inner arch; the 1 px left lip catches the
    # same upper-left key light as the approved wall.
    for y, left, right in arch_spans(x0 - 9, y0 - 9, x1 + 9, y1):
        rect(draw, left, y, right, y, DEEP_0)
    for y, left, right in arch_spans(x0 - 8, y0 - 8, x1 + 8, y1):
        rect(draw, left, y, right, y, DEEP_4)
    for y, left, right in arch_spans(x0 - 7, y0 - 7, x1 + 7, y1):
        rect(draw, left, y, right, y, DEEP_2)
    # The throat.
    for y, left, right in arch_spans(x0, y0, x1, y1):
        t = (y - y0) / float(max(1, y1 - y0))
        color = (
            int(round(29 + 7 * t)),
            int(round(26 + 5 * t)),
            int(round(28 + 5 * t)),
            255,
        )
        rect(draw, left, y, right, y, color)
    # Rim light: left = pale, right = dark.
    for y, left, right in arch_spans(x0 - 8, y0 - 8, x1 + 8, y1):
        px(draw, left, y, DEEP_HI)
        px(draw, left + 1, y, DEEP_5)
        px(draw, right, y, DEEP_INK)
        px(draw, right - 1, y, DEEP_0)
    for y in (y0 - 8, y0 - 7):
        span = next(arch_spans(x0 - 8, y, x1 + 8, y1))
        rect(draw, span[1] + 1, y, span[2] - 1, y,
             DEEP_HI if y == y0 - 8 else DEEP_5)


def deep_pipe_h(img: Image.Image, x0: int, x1: int, y: int) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x0, y, x1, y + 7, IRON_1)
    rect(draw, x0, y, x1, y, IRON_HI)
    rect(draw, x0, y + 7, x1, y + 7, DEEP_INK)
    for bx in range(x0 + 20, x1, 84):
        rect(draw, bx, y - 1, bx + 3, y + 8, IRON_2)
        px(draw, bx, y - 1, DEEP_HI)
        px(draw, bx + 2, y + 6, IRON_0)


def deep_pipe_v(img: Image.Image, x: int, y0: int, y1: int) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x, y0, x + 7, y1, IRON_1)
    rect(draw, x, y0, x, y1, IRON_2)
    rect(draw, x + 7, y0, x + 7, y1, DEEP_INK)
    for by in range(y0 + 26, y1 - 4, 62):
        rect(draw, x - 1, by, x + 8, by + 3, IRON_2)
        px(draw, x, by, IRON_HI)
    # A hand valve.
    vy = y0 + 34
    draw.ellipse((x - 4, vy - 4, x + 11, vy + 11), outline=IRON_2, width=1)
    rect(draw, x + 3, vy - 8, x + 4, vy + 14, IRON_2)
    px(draw, x + 3, vy - 8, IRON_HI)


def deep_chain(img: Image.Image, x: int, y0: int, y1: int) -> None:
    draw = ImageDraw.Draw(img)
    y = y0
    toggle = 0
    while y < y1 - 5:
        if toggle % 2 == 0:
            rect(draw, x - 1, y, x + 1, y, IRON_2)
            px(draw, x - 1, y, IRON_HI)
            px(draw, x - 1, y + 1, DEEP_INK)
            px(draw, x + 1, y + 1, DEEP_INK)
        else:
            rect(draw, x, y, x, y + 2, IRON_1)
            px(draw, x, y, IRON_2)
        y += 3
        toggle += 1
    # A small hook; never a large silhouette.
    rect(draw, x - 1, y1 - 5, x + 1, y1 - 3, IRON_2)
    px(draw, x - 1, y1 - 5, IRON_HI)
    rect(draw, x, y1 - 2, x, y1, IRON_1)


def deep_catwalk(img: Image.Image, x0: int, x1: int, y: int) -> None:
    draw = ImageDraw.Draw(img)
    rect(draw, x0, y, x1, y + 5, WOOD_1)
    rect(draw, x0, y, x1, y, WOOD_2)
    rect(draw, x0, y + 5, x1, y + 5, DEEP_INK)
    for bx in range(x0 + 12, x1, 48):
        rect(draw, bx, y + 1, bx, y + 4, WOOD_0)
    # Sparse 1 px rail posts, low enough not to read as a fence.
    for bx in range(x0 + 18, x1, 72):
        rect(draw, bx, y - 12, bx, y - 1, IRON_1)
        px(draw, bx, y - 12, IRON_2)


def deep_gear(img: Image.Image, cx: int, cy: int, radius: int) -> None:
    draw = ImageDraw.Draw(img)
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                 fill=DEEP_0)
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                 outline=DEEP_4, width=1)
    for index in range(10):
        angle = math.tau * index / 10.0
        tx = cx + int(round(math.cos(angle) * (radius - 2)))
        ty = cy + int(round(math.sin(angle) * (radius - 2)))
        rect(draw, tx - 3, ty - 3, tx + 3, ty + 3, DEEP_0)
        px(draw, tx - 2, ty - 3, DEEP_3)
    draw.ellipse((cx - radius // 3, cy - radius // 3,
                  cx + radius // 3, cy + radius // 3), fill=DEEP_INK)
    draw.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=DEEP_2)
    px(draw, cx - 3, cy - 3, DEEP_4)


def make_deep() -> Image.Image:
    img = Image.new("RGBA", (W, H), DEEP_SKY)
    draw = ImageDraw.Draw(img)
    # A calm far wall.  The top 100 px are hidden by the approved wall's arch
    # spandrels; the visible band is composed between y=100 and y=300.
    deep_brick(img, 0, 0, W - 1, 359)
    # Ceiling mass and a single far wall plate, both very low contrast.
    rect(draw, 0, 0, W - 1, 84, (31, 28, 31, 255))
    rect(draw, 0, 84, W - 1, 94, WOOD_0)
    rect(draw, 0, 84, W - 1, 84, WOOD_1)
    rect(draw, 0, 94, W - 1, 94, DEEP_INK)
    # A distant arcade: seven bays, each 150 px wide, every 220 px.  The
    # spacing is deliberately smaller than the approved wall's giant arch, so
    # scale alone reads as distance.
    for index in range(9):
        x0 = 58 + index * 220
        deep_arch(img, x0, 112, x0 + 150, 300)
    # Piers between the bays.
    for index in range(9):
        px0 = 208 + index * 220
        rect(draw, px0, 100, px0 + 14, 300, DEEP_2)
        rect(draw, px0, 100, px0, 300, DEEP_5)
        rect(draw, px0 + 1, 100, px0 + 1, 300, DEEP_4)
        rect(draw, px0 + 13, 100, px0 + 13, 300, DEEP_0)
        rect(draw, px0 + 14, 100, px0 + 14, 300, DEEP_INK)
        rect(draw, px0 - 2, 100, px0 + 16, 104, DEEP_4)
        rect(draw, px0 - 2, 100, px0 + 16, 100, DEEP_HI)
        rect(draw, px0 - 2, 296, px0 + 16, 300, DEEP_3)
    # Long horizontal services and a few vertical risers.
    deep_pipe_h(img, 0, W - 1, 132)
    deep_pipe_h(img, 0, W - 1, 186)
    for x in (120, 560, 1000, 1440, 1780):
        deep_pipe_v(img, x, 96, 300)
    # Catwalks and gear silhouettes sit in the lower half of the far hall.
    for x0 in (86, 306, 526, 746, 966, 1186, 1406, 1626):
        deep_catwalk(img, x0, x0 + 126, 236)
    deep_gear(img, 372, 210, 28)
    deep_gear(img, 1032, 214, 34)
    deep_gear(img, 1472, 222, 24)
    # Chains: never wider than 3 px, always above the catwalk line.
    for x, end in ((168, 170), (258, 146), (388, 176), (498, 152),
                   (608, 182), (718, 150), (828, 172), (938, 148),
                   (1048, 180), (1158, 152), (1268, 174), (1378, 148),
                   (1488, 178), (1598, 154), (1708, 174), (1818, 150)):
        deep_chain(img, x, 96, end)
    # A low, dim furnace bed under the far hall; the moving embers are added
    # by the world-front atmosphere layer, not here.
    for x0, x1 in ((672, 930), (1330, 1520)):
        rect(draw, x0, 291, x1, 298, (34, 26, 22, 255))
        rect(draw, x0, 291, x1, 291, FIRE_DARK)
        for x in range(x0 + 6, x1 - 4, 18):
            px(draw, x, 294, FIRE_MID)
            if (x // 18) % 3 == 0:
                px(draw, x + 3, 292, FIRE_LIGHT)
    # A single quiet floor line ties the far hall to the approved plinth.
    rect(draw, 0, 299, W - 1, 309, DEEP_2)
    rect(draw, 0, 299, W - 1, 299, DEEP_4)
    rect(draw, 0, 309, W - 1, 309, DEEP_INK)
    # Lower hall: dark, no bright detail, so the bridge pit still reads as a
    # drop rather than a lit room.
    rect(draw, 0, 310, W - 1, H - 1, (27, 25, 27, 255))
    return img


def make_depth_mask() -> Image.Image:
    """White only in the two deep arch throats; transparent everywhere else.

    The 2 px inner lip is left opaque, so the runtime overlay never covers the
    approved rim.  The mask is aligned to the unchanged Back sprite.
    """
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Entry blind arch: inner brick wall at x153..281, y103..297 (inset 7).
    for y, left, right in arch_spans(153, 103, 281, 297):
        if y < 105:
            continue
        rect(draw, left + 2, y, right - 2, y, (255, 255, 255, 255))
    # Bridge-hall giant arch: inner wall at x616..994, y102..297 (inset 10).
    for y, left, right in arch_spans(616, 102, 994, 297):
        if y < 104:
            continue
        rect(draw, left + 2, y, right - 2, y, (255, 255, 255, 255))
    return img


def make_smoke() -> Image.Image:
    """96x48 soft smoke mask; the runtime tints it and draws at alpha 0.12-0.22.

    The alpha is quantised to 16 steps so the plume keeps a pixel-art edge when
    scaled 1:1.  The body is a chain of three low ellipses, not a full-screen
    wash.
    """
    img = Image.new("RGBA", (96, 48), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    lobes = (
        (27.0, 30.0, 20.0, 13.0, 235),
        (48.0, 23.0, 23.0, 15.0, 255),
        (69.0, 31.0, 19.0, 12.0, 225),
        (45.0, 38.0, 30.0, 9.0, 155),
    )
    for cx, cy, rx, ry, peak in lobes:
        for y in range(0, 48):
            for x in range(0, 96):
                dx = (x - cx) / rx
                dy = (y - cy) / ry
                d = dx * dx + dy * dy
                if d >= 1.0:
                    continue
                alpha = int(peak * (1.0 - d) * (1.0 - d))
                alpha = (alpha // 16) * 16
                if alpha <= 0:
                    continue
                old = img.getpixel((x, y))
                if alpha > old[3]:
                    draw.point((x, y), fill=(255, 238, 214, alpha))
    # A few 1 px holes keep it from reading as a solid sticker.
    for x, y in ((34, 23), (45, 27), (57, 20), (66, 28), (40, 34)):
        img.putpixel((x, y), (255, 238, 214, 64))
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    deep = make_deep()
    deep.save(os.path.join(OUT, "interior_deep_1880x360.png"))
    mask = make_depth_mask()
    mask.save(os.path.join(OUT, "interior_depth_mask_1880x360.png"))
    make_smoke().save(os.path.join(OUT, "rift_furnace_smoke_96x48.png"))
    print("WROTE interior_deep_1880x360.png", deep.size)
    print("WROTE interior_depth_mask_1880x360.png", mask.size)
    print("WROTE rift_furnace_smoke_96x48.png", (96, 48))
    print("RIFT_DEPTH_DONE", OUT)


if __name__ == "__main__":
    main()
