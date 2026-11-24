"""V3 review only: original drawn cylinders, unchanged comparison staging."""
from pathlib import Path
from math import sqrt
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
GAME = ROOT / '基础场景原型'
PACK = ROOT / '素材库/古遗迹候选/01_szadi_pixel_platformer_world/extracted_map'
# Warm grey lights, purple-brown shadows. Discrete material colours, no gradients.
EDGE = (66, 55, 62, 255)
DARK = (89, 74, 81, 255)
SHADE = (113, 96, 100, 255)
MID = (143, 128, 126, 255)
LIGHT = (167, 154, 146, 255)
TOP = (181, 169, 158, 255)
CHIP = (151, 136, 130, 255)


def cylinder(height=108, broken=False, base=False):
    """A single stone, not brick modules: rounded ends, mild waist."""
    im = Image.new('RGBA', (52, height))
    mask = Image.new('L', im.size)
    md = ImageDraw.Draw(mask)
    top_y = 0
    cap_depth = 9 if not base else 8
    cy = cap_depth // 2
    # Profile is gently curved, never an angular pedestal or tray.
    for y in range(cy, height - 4):
        t = (y-cy) / max(1, height-5-cy)
        half = 16 + round(5 * abs(2*t-1)**2)
        if base:
            half = 20
        md.line((26-half, y, 26+half-1, y), fill=255)
    md.ellipse((5 if not base else 6, height-10, 46 if not base else 45, height-1), fill=255)
    md.ellipse((5 if not base else 6, top_y, 46 if not base else 45, cap_depth), fill=255)
    pix = im.load()
    mp = mask.load()
    # Hard colour steps wrap the circular cross section; highlight is left of centre.
    for y in range(height):
        xs = [x for x in range(52) if mp[x, y]]
        if not xs:
            continue
        lo, hi = min(xs), max(xs)
        for x in xs:
            u = (x-lo) / max(1, hi-lo)
            color = EDGE if u > .95 else DARK if u > .82 else SHADE if u > .65 else MID if u > .34 else LIGHT if u > .10 else MID
            if y >= height-3:
                color = DARK if u < .77 else EDGE
            pix[x, y] = color
    d = ImageDraw.Draw(im)
    # A few large, low-contrast weathered planes, not a noise/brick texture.
    if not base:
        d.polygon([(14, 22), (18, 19), (19, 39), (16, 45), (14, 41)], fill=MID)
        d.polygon([(21, height-39), (28, height-43), (29, height-28), (25, height-23), (21, height-25)], fill=CHIP)
        d.line([(11, height-22), (13, height-16), (18, height-13)], fill=CHIP)
    # Flat ellipse reads as top surface, distinct from the vertically shaded body.
    d.ellipse((5 if not base else 6, 0, 46 if not base else 45, cap_depth), fill=CHIP)
    d.ellipse((7 if not base else 8, 0, 43, cap_depth-2), fill=TOP)
    d.arc((5 if not base else 6, 0, 46 if not base else 45, cap_depth), 0, 165, fill=SHADE)
    d.line([(10, 2), (16, 1), (30, 1)], fill=(193, 182, 169, 255))
    if broken:
        # Irregular exposed cross-section, retaining a cylindrical silhouette.
        cut = [(5, 5), (9, 5), (9, 2), (16, 2), (19, 5), (25, 4), (25, 0), (31, 1), (34, 4), (40, 3), (44, 7), (46, 8)]
        d.polygon([(0, 0), (51, 0), (51, 8)] + list(reversed(cut)) + [(0, 5)], fill=(0, 0, 0, 0))
        d.polygon(cut + [(43, 11), (35, 12), (25, 10), (15, 12), (7, 9)], fill=CHIP)
        d.polygon([(9, 5), (16, 3), (19, 6), (27, 6), (30, 3), (36, 6), (40, 5), (42, 8), (32, 9), (21, 8), (13, 9)], fill=TOP)
        d.line([(7, 9), (15, 12), (25, 10), (35, 12), (43, 11)], fill=SHADE)
    if base:
        cracks = [[(29, 3), (26, 5), (28, 8), (25, 11), (25, 17)], [(12, 13), (15, 15), (15, 19)]]
    else:
        cracks = [[(29, 5), (27, 10), (29, 17), (26, 23), (27, 31)],
                  [(14, height//2-2), (17, height//2+2), (16, height//2+10), (20, height//2+14)],
                  [(34, height-26), (31, height-21), (32, height-14)]]
    for line in cracks:
        d.line(line, fill=DARK, width=1)
    if not base:
        d.line([(26, 23), (23, 25), (22, 29)], fill=SHADE)
        d.line([(17, height//2+2), (21, height//2)], fill=SHADE)
    # Clip surface marks to the stone. Transparent cut stays transparent.
    alpha = im.getchannel('A')
    from PIL import ImageChops
    im.putalpha(ImageChops.darker(alpha, mask))
    return im


def fallen():
    im = Image.new('RGBA', (56, 28))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, 55, 27), radius=7, fill=EDGE)
    d.rectangle((7, 1, 48, 25), fill=SHADE)
    d.rectangle((6, 2, 48, 6), fill=LIGHT)
    d.rectangle((6, 7, 48, 15), fill=MID)
    d.rectangle((6, 16, 48, 22), fill=SHADE)
    d.ellipse((0, 0, 13, 27), fill=CHIP)
    d.ellipse((1, 1, 11, 24), fill=TOP)
    d.line([(7, 2), (5, 7), (7, 12), (5, 17)], fill=SHADE)
    d.ellipse((44, 0, 55, 27), fill=DARK)
    d.arc((44, 0, 55, 27), 185, 285, fill=CHIP)
    d.line([(24, 3), (27, 7), (25, 11), (29, 15)], fill=DARK)
    d.line([(38, 20), (35, 19), (33, 22)], fill=DARK)
    return im


def generate():
    w, h, floor = 640, 280, 216
    scene = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(scene)
    for y in range(h):
        t = min(y / floor, 1)
        color = tuple(round(v*(1-t)+u*t) for v, u in zip((29, 31, 40), (49, 48, 54)))
        d.line((0, y, w, y), fill=(*color, 255))
    high, low = cylinder(), cylinder(82, broken=True)
    scene.alpha_composite(high, (123, floor-107))
    scene.alpha_composite(low, (478, floor-81))
    scene.alpha_composite(cylinder(24, base=True), (197, floor-23))
    scene.alpha_composite(fallen(), (542, floor-20))
    hero = Image.open(GAME / 'assets/characters/male_hero-idle.png').convert('RGBA').crop((0, 0, 128, 128))
    talisman = Image.open(GAME / 'assets/talisman/talisman_gold.png').convert('RGBA')
    hero.alpha_composite(talisman, (64, 63))
    scene.alpha_composite(hero, (312-59, floor-79))
    stele = Image.open(GAME / 'assets/tutorial_stele/tutorial_stele_grey.png').convert('RGBA')
    scene.alpha_composite(stele, (365, floor-stele.height+1))
    terrain = Image.open(GAME / 'assets/map/ruin_platform_tiles.png').convert('RGBA')
    for x in range(0, w, terrain.width):
        scene.alpha_composite(terrain, (x, floor))
    a = Image.open(PACK / 'main_lev_buildA.png').convert('RGBA')
    for box, x in [((260, 40, 275, 48), 101), ((282, 40, 304, 48), 174), ((326, 40, 338, 48), 451), ((344, 40, 366, 48), 586)]:
        rock = a.crop(box)
        scene.alpha_composite(rock, (x, floor-rock.height+1))
    font = ImageFont.truetype(str(GAME / 'assets/fonts/tutorial_zh.ttf'), 12)
    d = ImageDraw.Draw(scene)
    d.text((16, 15), '圆柱重绘示意·非实机', font=font, fill='#c1b8b1')
    for xy, text in [((126, 252), '高残柱'), ((200, 252), '柱座'), ((480, 252), '断柱')]:
        d.text(xy, text, font=font, fill='#a99f97')
    scene = scene.convert('RGB').resize((1280, 560), Image.Resampling.NEAREST)
    scene.save(OUT / 'concept_v3.png')


if __name__ == '__main__':
    generate()
