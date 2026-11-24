"""Review-only pixel collage. Run with the project's approved Conda Python."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[1]
PACK = ROOT / '素材库/古遗迹候选/01_szadi_pixel_platformer_world/extracted_map'
GAME = ROOT / '基础场景原型'


def quiet_stone(im):
    """Non-destructive concept palette: gray-brown, quieter than terrain."""
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            lum = .299 * r + .587 * g + .114 * b
            px[x, y] = (round(36 + .64 * lum), round(34 + .60 * lum),
                        round(34 + .58 * lum), a)
    return im


def shaft(b, height):
    # A 24px masonry module; last module is cropped, never resized.
    tile = quiet_stone(b.crop((66, 290, 94, 314)))
    out = Image.new('RGBA', (28, height))
    for y in range(0, height, 24):
        piece = tile.crop((0, 0, 28, min(24, height-y)))
        out.alpha_composite(piece, (0, y))
    return out


def pillar(b, broken=False):
    cap = quiet_stone(b.crop((54, 272, 106, 290)))
    # Same corbel turned vertically for a wide, grounded foot; derived use.
    foot = cap.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    height = 82 if broken else 108
    out = Image.new('RGBA', (52, height))
    stem = shaft(b, 64 if broken else 72)
    if broken:
        # Hand-cut fracture profile; no new motifs or emissive decoration.
        d = ImageDraw.Draw(stem)
        d.polygon([(0, 0), (27, 0), (27, 6), (23, 6), (23, 9),
                   (20, 9), (20, 5), (15, 5), (15, 3), (10, 3),
                   (10, 7), (5, 7), (5, 4), (0, 4)], fill=(0, 0, 0, 0))
        # Small exposed stone edge, deliberately local rather than new art.
        for x, y, n in [(0, 4, 5), (5, 7, 5), (10, 3, 5),
                        (15, 5, 5), (20, 9, 3), (23, 6, 5)]:
            d.line((x, y, x+n-1, y), fill=(94, 88, 85, 255))
        out.alpha_composite(stem, (12, 0))
    else:
        # Mild chip on the upper left of the mostly complete capital.
        cd = ImageDraw.Draw(cap)
        cd.polygon([(0, 0), (7, 0), (7, 2), (4, 2), (4, 4), (0, 4)],
                   fill=(0, 0, 0, 0))
        out.alpha_composite(cap, (0, 0))
        out.alpha_composite(stem, (12, 18))
    out.alpha_composite(foot, (0, height-18))
    return out


def generate():
    b = Image.open(PACK / 'main_lev_buildB.png').convert('RGBA')
    a = Image.open(PACK / 'main_lev_buildA.png').convert('RGBA')
    w, h, floor = 640, 280, 216
    scene = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(scene)
    # Approximate neutral scene backdrop, not a new environment proposal.
    for y in range(h):
        t = min(y / floor, 1)
        color = tuple(round(v*(1-t)+u*t) for v, u in
                      zip((29, 31, 40), (49, 48, 54)))
        d.line((0, y, w, y), fill=(*color, 255))

    high, low = pillar(b), pillar(b, True)
    scene.alpha_composite(high, (123, floor-high.height+1))
    scene.alpha_composite(low, (478, floor-low.height+1))

    # A low remnant beside the main column, deliberately subordinate.
    base = Image.new('RGBA', (52, 24))
    base.alpha_composite(shaft(b, 6), (12, 0))
    foot = quiet_stone(b.crop((54, 272, 106, 290))).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    base.alpha_composite(foot, (0, 6))
    scene.alpha_composite(base, (197, floor-23))

    # Fallen masonry: 90-degree rotation only, plus local fractured cut.
    fallen = shaft(b, 56).transpose(Image.Transpose.ROTATE_90)
    fd = ImageDraw.Draw(fallen)
    fd.polygon([(0, 0), (8, 0), (8, 2), (4, 2), (4, 5), (0, 5)], fill=(0, 0, 0, 0))
    scene.alpha_composite(fallen, (542, floor-20))

    # Current character scale and tutorial stele, unscaled originals.
    hero = Image.open(GAME / 'assets/characters/male_hero-idle.png').convert('RGBA').crop((0, 0, 128, 128))
    talisman = Image.open(GAME / 'assets/talisman/talisman_gold.png').convert('RGBA')
    hero.alpha_composite(talisman, (64, 63))
    # Actor anchor (x, floor) with the existing Sprite2D offset(-59,-79).
    scene.alpha_composite(hero, (312-59, floor-79))
    stele = Image.open(GAME / 'assets/tutorial_stele/tutorial_stele_grey.png').convert('RGBA')
    scene.alpha_composite(stele, (365, floor-stele.height+1))

    # Exact currently used 192x32 terrain, in its existing 1:1 scale.
    terrain = Image.open(GAME / 'assets/map/ruin_platform_tiles.png').convert('RGBA')
    for x in range(0, w, terrain.width):
        scene.alpha_composite(terrain, (x, floor))

    # Small original loose stones, no large mound or new gameplay obstacle.
    for box, x in [((260, 40, 275, 48), 101),
                   ((282, 40, 304, 48), 174),
                   ((326, 40, 338, 48), 451),
                   ((344, 40, 366, 48), 586)]:
        rock = a.crop(box)
        scene.alpha_composite(rock, (x, floor-rock.height+1))

    font = ImageFont.truetype(str(GAME / 'assets/fonts/tutorial_zh.ttf'), 12)
    d = ImageDraw.Draw(scene)
    d.text((16, 15), '庭院地面物件 · 概念拼图，非实机', font=font, fill='#c1b8b1')
    d.text((126, 252), '高残柱', font=font, fill='#a99f97')
    d.text((200, 252), '柱座', font=font, fill='#a99f97')
    d.text((480, 252), '断柱', font=font, fill='#a99f97')
    scene.convert('RGB').resize((w*2, h*2), Image.Resampling.NEAREST).save(OUT / 'concept.png')


if __name__ == '__main__':
    generate()
