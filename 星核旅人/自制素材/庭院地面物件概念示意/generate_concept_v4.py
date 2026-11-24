"""V4 concept only. Original Doric-inspired pixel columns; unchanged V3 staging."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
GAME = ROOT / '基础场景原型'
PACK = ROOT / '素材库/古遗迹候选/01_szadi_pixel_platformer_world/extracted_map'
EDGE = (66, 55, 62, 255)
DARK = (89, 74, 81, 255)
SHADE = (113, 96, 100, 255)
MID = (143, 128, 126, 255)
LIGHT = (167, 154, 146, 255)
TOP = (181, 169, 158, 255)
CHIP = (151, 136, 130, 255)


def round_row(im, y, left, right, dark=False):
    """Hard-edged value bands around one circular cross-section, not a gradient."""
    for x in range(left, right + 1):
        u = (x-left) / max(1, right-left)
        c = MID if u < .09 else LIGHT if u < .35 else MID if u < .62 else SHADE if u < .80 else DARK if u < .96 else EDGE
        if dark:
            c = SHADE if u < .62 else DARK if u < .90 else EDGE
        im.putpixel((x, y), c)


def base_ring(im, bottom):
    """Low, circular footing with a distinct upper ledge and contact shadow."""
    d = ImageDraw.Draw(im)
    top = bottom - 9
    d.ellipse((10, top, 41, top+5), fill=TOP)
    for y, inset in [(top+3, 1), (top+4, 0), (top+5, 0), (top+6, 0), (top+7, 1)]:
        round_row(im, y, 9+inset, 42-inset)
    d.arc((9, top+2, 42, top+8), 0, 180, fill=DARK)
    d.line((12, bottom-1, 39, bottom-1), fill=DARK)
    d.line((15, bottom, 36, bottom), fill=EDGE)


def column(height=108, broken=False, stump=False):
    """Straight shaft, slight upward taper. Capital/base are separate components."""
    im = Image.new('RGBA', (52, height))
    d = ImageDraw.Draw(im)
    start = 0 if broken or stump else 15
    end = height-9
    # 21px upper diameter to 23px lower diameter; no waist/concave profile.
    for y in range(start, end):
        step = 1 if (y-start) >= (end-start)*.58 else 0
        round_row(im, y, 15-step, 35+step)
    # A few restrained shallow grooves. Not a bark pattern or full-height cracks.
    if not stump:
        for x, color, shine in [(18, CHIP, TOP), (24, SHADE, CHIP), (31, DARK, SHADE)]:
            d.line((x, start+5, x, end-4), fill=color)
            d.line((x+1, start+5, x+1, end-4), fill=shine)
        d.line([(27, start+23), (25, start+26), (26, start+31)], fill=DARK)
        d.line([(16, end-20), (19, end-17), (19, end-13)], fill=SHADE)
        d.polygon([(16, start+11), (18, start+9), (19, start+13), (17, start+16)], fill=CHIP)
    base_ring(im, height-1)
    if broken or stump:
        # Broken same-diameter shaft, NOT a flared trunk top.
        cut = [(15, 3), (18, 2), (20, 4), (23, 3), (25, 0), (28, 1), (29, 3), (32, 2), (35, 4), (35, 6), (30, 8), (23, 7), (18, 8), (15, 6)]
        d.polygon([(14, 0), (36, 0), (36, 4), (32, 2), (29, 3), (28, 1), (25, 0), (23, 3), (20, 4), (18, 2), (14, 3)], fill=(0, 0, 0, 0))
        d.polygon(cut, fill=TOP)
        d.line([(15, 6), (18, 8), (23, 7), (30, 8), (35, 6)], fill=SHADE)
        d.line([(25, 2), (24, 4), (27, 6)], fill=CHIP)
    else:
        # Roman Doric reference: thin square abacus; convex echinus; short neck rings.
        d.polygon([(9, 0), (41, 0), (43, 2), (8, 2)], fill=TOP)
        d.rectangle((8, 3, 43, 4), fill=MID)
        d.line((8, 3, 32, 3), fill=LIGHT)
        d.line((8, 5, 43, 5), fill=DARK)
        for y, lo, hi in [(6, 10, 41), (7, 10, 41), (8, 11, 40), (9, 13, 38), (10, 15, 36)]:
            round_row(im, y, lo, hi)
        d.line((16, 11, 35, 11), fill=DARK)
        round_row(im, 12, 15, 36)
        round_row(im, 13, 14, 37)
        round_row(im, 14, 14, 37, dark=True)
        round_row(im, 15, 15, 35, dark=True)
        d.point((10, 2), fill=CHIP)
        d.line((38, 1, 40, 1), fill=CHIP)
    return im


def fallen():
    im = Image.new('RGBA', (56, 28))
    d = ImageDraw.Draw(im)
    # Same 22px shaft diameter, light from above-left.
    d.rectangle((7, 4, 49, 24), fill=MID)
    for y0, y1, color in [(4, 6, LIGHT), (7, 11, MID), (12, 17, SHADE), (18, 22, DARK), (23, 24, EDGE)]:
        d.rectangle((7, y0, 49, y1), fill=color)
    d.line((12, 8, 46, 8), fill=CHIP)
    d.line((12, 15, 45, 15), fill=DARK)
    d.ellipse((45, 4, 55, 24), fill=DARK)
    d.arc((45, 4, 55, 24), 190, 280, fill=SHADE)
    d.polygon([(6, 4), (10, 6), (12, 11), (11, 19), (7, 24), (3, 22), (1, 16), (2, 9)], fill=CHIP)
    d.polygon([(5, 6), (8, 7), (10, 12), (9, 18), (6, 22), (3, 18), (3, 11)], fill=TOP)
    d.line([(6, 7), (5, 12), (7, 16)], fill=SHADE)
    d.line([(29, 5), (27, 8), (30, 11)], fill=DARK)
    return im


def generate():
    w, h, floor = 640, 280, 216
    scene = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(scene)
    for y in range(h):
        t = min(y / floor, 1)
        color = tuple(round(v*(1-t)+u*t) for v, u in zip((29, 31, 40), (49, 48, 54)))
        d.line((0, y, w, y), fill=(*color, 255))
    scene.alpha_composite(column(), (123, floor-107))
    scene.alpha_composite(column(82, broken=True), (478, floor-81))
    scene.alpha_composite(column(24, stump=True), (197, floor-23))
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
        scene.alpha_composite(a.crop(box), (x, floor-7))
    font = ImageFont.truetype(str(GAME / 'assets/fonts/tutorial_zh.ttf'), 12)
    d = ImageDraw.Draw(scene)
    d.text((16, 15), '多立克式残柱示意 · 非实机', font=font, fill='#c1b8b1')
    for xy, text in [((126, 252), '高残柱'), ((200, 252), '柱座'), ((480, 252), '断柱')]:
        d.text(xy, text, font=font, fill='#a99f97')
    scene.convert('RGB').resize((1280, 560), Image.Resampling.NEAREST).save(OUT / 'concept_v4.png')


if __name__ == '__main__':
    generate()
