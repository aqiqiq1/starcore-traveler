"""Review-only v2. Original crops/scale/layout; face-aware derived stone palette."""
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFont
sys.dont_write_bytecode = True
import generate_concept as v1

OUT = Path(__file__).resolve().parent
PACK, GAME = v1.PACK, v1.GAME

# Explicit source swatches retain Szadi's masonry texture, chips and mortar.
# No exposure pass, smooth lighting, glow or changes to the source PNGs.
PALETTE = {
    (15, 13, 14): (42, 39, 38),       # deep cavity
    (17, 18, 21): (61, 57, 53),       # recessed joints
    (40, 28, 28): (91, 85, 77),       # stone shade
    (51, 37, 37): (126, 117, 104),    # broad face
    (78, 49, 49): (157, 145, 126),    # original chipped bevel
    (104, 65, 65): (184, 170, 146),   # original small light pixels
}


def stone(im, part):
    """Discrete upper-left face light, evaluated in final part orientation."""
    im = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if not a:
                continue
            c = PALETTE[(r, g, b)]
            cavity = (r, g, b) in ((15, 13, 14), (17, 18, 21))
            if part == 'shaft':
                # Right-hand return is seven logical pixels, not a new contour.
                factor = .73 if x >= 22 else (.88 if x >= 20 else 1.0)
                if x <= 3:
                    factor *= 1.06
            else:
                factor = .80 if x >= 36 else (.92 if x >= 29 else 1.0)
                if x <= 16:
                    factor *= 1.04
                if part == 'cap' and y <= 2 and not cavity:
                    # Broad lit upper slab, still using the original cracks.
                    c = tuple(min(199, n + 23) for n in c)
                if part == 'foot':
                    if y <= 2 and not cavity:
                        c = tuple(min(190, n + 17) for n in c)
                    if y >= 15:
                        # The flipped corbel is re-lit, not lit from underneath.
                        factor *= .87
                    if y == 17:
                        c = (66, 60, 54)  # 1px contact shade inside original alpha
            if cavity:
                # Keep joints readable without making every brick black-lined.
                factor = max(.86, factor)
            im.putpixel((x, y), (*[round(n * factor) for n in c], a))
    return im


def shaft(b, height):
    tile = stone(b.crop((66, 290, 94, 314)), 'shaft')
    out = Image.new('RGBA', (28, height))
    for y in range(0, height, 24):
        out.alpha_composite(tile.crop((0, 0, 28, min(24, height-y))), (0, y))
    return out


def foot(b):
    raw = b.crop((54, 272, 106, 290)).transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    return stone(raw, 'foot')


def pillar(b, broken=False):
    cap = stone(b.crop((54, 272, 106, 290)), 'cap')
    height = 82 if broken else 108
    out = Image.new('RGBA', (52, height))
    stem = shaft(b, 64 if broken else 72)
    if broken:
        d = ImageDraw.Draw(stem)
        d.polygon([(0, 0), (27, 0), (27, 6), (23, 6), (23, 9),
                   (20, 9), (20, 5), (15, 5), (15, 3), (10, 3),
                   (10, 7), (5, 7), (5, 4), (0, 4)], fill=(0, 0, 0, 0))
        for x, y, n in [(0, 4, 5), (5, 7, 5), (10, 3, 5),
                         (15, 5, 5), (20, 9, 3), (23, 6, 5)]:
            d.line((x, y, x+n-1, y), fill=(174, 159, 136, 255)
                   if x < 20 else (127, 116, 100, 255))
        out.alpha_composite(stem, (12, 0))
    else:
        d = ImageDraw.Draw(cap)
        d.polygon([(0, 0), (7, 0), (7, 2), (4, 2), (4, 4), (0, 4)],
                  fill=(0, 0, 0, 0))
        # A restrained cast shade only under the capital, not down the whole shaft.
        for y, strength in ((0, .78), (1, .86), (2, .94)):
            for x in range(stem.width):
                r, g, bb, a = stem.getpixel((x, y))
                stem.putpixel((x, y), (round(r*strength), round(g*strength),
                                      round(bb*strength), a))
        out.alpha_composite(cap, (0, 0))
        out.alpha_composite(stem, (12, 18))
    out.alpha_composite(foot(b), (0, height-18))
    # Same alpha silhouette and size as the approved v1 collage.
    assert out.getchannel('A').tobytes() == v1.pillar(b, broken).getchannel('A').tobytes()
    return out


def fallen_piece(b):
    # Rotate geometry only, then light from screen upper-left (not from below).
    raw = b.crop((66, 290, 94, 314))
    assembly = Image.new('RGBA', (28, 56))
    for y in range(0, 56, 24):
        assembly.alpha_composite(raw.crop((0, 0, 28, min(24, 56-y))), (0, y))
    out = assembly.transpose(Image.Transpose.ROTATE_90)
    for y in range(out.height):
        for x in range(out.width):
            r, g, bb, a = out.getpixel((x, y))
            if not a:
                continue
            c = PALETTE[(r, g, bb)]
            factor = 1.08 if y <= 5 else (.93 if y <= 15 else .72)
            if (r, g, bb) in ((15, 13, 14), (17, 18, 21)):
                factor = max(.85, factor)
            out.putpixel((x, y), (*[round(n*factor) for n in c], a))
    ImageDraw.Draw(out).polygon([(0, 0), (8, 0), (8, 2), (4, 2), (4, 5), (0, 5)],
                               fill=(0, 0, 0, 0))
    return out


def generate():
    b = Image.open(PACK / 'main_lev_buildB.png').convert('RGBA')
    a = Image.open(PACK / 'main_lev_buildA.png').convert('RGBA')
    w, h, floor = 640, 280, 216
    scene = Image.new('RGBA', (w, h))
    d = ImageDraw.Draw(scene)
    for y in range(h):
        t = min(y / floor, 1)
        color = tuple(round(v*(1-t)+u*t) for v, u in
                      zip((29, 31, 40), (49, 48, 54)))
        d.line((0, y, w, y), fill=(*color, 255))

    high, low = pillar(b), pillar(b, True)
    scene.alpha_composite(high, (123, floor-high.height+1))
    scene.alpha_composite(low, (478, floor-low.height+1))
    base = Image.new('RGBA', (52, 24))
    base.alpha_composite(shaft(b, 6), (12, 0))
    base.alpha_composite(foot(b), (0, 6))
    scene.alpha_composite(base, (197, floor-23))
    scene.alpha_composite(fallen_piece(b), (542, floor-20))

    hero = Image.open(GAME / 'assets/characters/male_hero-idle.png').convert('RGBA').crop((0, 0, 128, 128))
    talisman = Image.open(GAME / 'assets/talisman/talisman_gold.png').convert('RGBA')
    hero.alpha_composite(talisman, (64, 63))
    scene.alpha_composite(hero, (312-59, floor-79))
    stele = Image.open(GAME / 'assets/tutorial_stele/tutorial_stele_grey.png').convert('RGBA')
    scene.alpha_composite(stele, (365, floor-stele.height+1))
    terrain = Image.open(GAME / 'assets/map/ruin_platform_tiles.png').convert('RGBA')
    for x in range(0, w, terrain.width):
        scene.alpha_composite(terrain, (x, floor))
    for box, x in [((260, 40, 275, 48), 101), ((282, 40, 304, 48), 174),
                   ((326, 40, 338, 48), 451), ((344, 40, 366, 48), 586)]:
        rock = a.crop(box)
        scene.alpha_composite(rock, (x, floor-rock.height+1))
    font = ImageFont.truetype(str(GAME / 'assets/fonts/tutorial_zh.ttf'), 12)
    d = ImageDraw.Draw(scene)
    d.text((16, 15), '庭院地面物件 · 概念拼图，非实机', font=font, fill='#c1b8b1')
    d.text((126, 252), '高残柱', font=font, fill='#a99f97')
    d.text((200, 252), '柱座', font=font, fill='#a99f97')
    d.text((480, 252), '断柱', font=font, fill='#a99f97')
    final = scene.convert('RGB').resize((1280, 560), Image.Resampling.NEAREST)
    original = Image.open(OUT / 'concept.png').convert('RGB')
    # Verify all differences are confined to the four approved decoration bounds.
    boxes = [(123, 109, 175, 217), (478, 135, 530, 217),
             (197, 193, 249, 217), (542, 196, 598, 224)]
    for y in range(560):
        for x in range(1280):
            if final.getpixel((x, y)) != original.getpixel((x, y)):
                assert any(l*2 <= x < r*2 and t*2 <= y < bt*2
                           for l, t, r, bt in boxes), (x, y)
    final.save(OUT / 'concept_v2.png')
    print('Saved concept_v2.png; alpha silhouettes and unchanged scene regions verified.')


if __name__ == '__main__':
    generate()
