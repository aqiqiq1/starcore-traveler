import os, math
from PIL import Image, ImageDraw
import gen_icons as G

OUT = G.OUT
INK = (9, 14, 20)
WARM_HI = (255, 238, 186)
COOL_HI = (188, 250, 251)


def bg(size=128):
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int((11, 20, 30)[i] + ((20, 40, 50)[i] - (11, 20, 30)[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return im


def halo(im, cx, cy, r, color, steps=3, alpha=22):
    for i in range(steps, 0, -1):
        rr = r + i * 5
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (int(alpha / i),))
        im.alpha_composite(layer)


# --- F: diagonal gem, multi-facet -------------------------------------------
def concept_f():
    im = bg()
    d = ImageDraw.Draw(im)
    cx, cy, r = 64, 62, 44
    halo(im, cx, cy, r, G.GOLD, 3, 18)
    # outline octagon
    pts = []
    for i in range(8):
        a = math.radians(22.5 + i * 45)
        pts.append((cx + math.cos(a) * (r + 3), cy + math.sin(a) * (r + 3)))
    d.polygon(pts, fill=INK)
    # body octagon
    pts = []
    for i in range(8):
        a = math.radians(22.5 + i * 45)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=G.GOLD_LO)
    # left/top gold half and right/bottom cyan half split by a diagonal
    d.polygon([(cx - r, cy - r), (cx + r, cy - r), (cx + r, cy + r), (cx - r, cy + r)], fill=G.GOLD)
    d.polygon([(cx - r, cy - r), (cx + r, cy + r), (cx - r, cy + r)], fill=G.CYAN)
    # facet lines: triangles from centre
    d.polygon([(cx, cy), (cx - r + 4, cy - r + 6), (cx + 6, cy - r + 4)], fill=WARM_HI)
    d.polygon([(cx, cy), (cx + r - 5, cy - r + 9), (cx + r - 3, cy + 6)], fill=COOL_HI)
    d.polygon([(cx, cy), (cx - r + 5, cy + r - 8), (cx - 8, cy + r - 4)], fill=(150, 106, 36))
    d.polygon([(cx, cy), (cx + r - 8, cy + r - 6), (cx + 4, cy + r - 3)], fill=G.CYAN_LO)
    # central spark
    d.polygon([(cx, cy - 6), (cx + 6, cy), (cx, cy + 6), (cx - 6, cy)], fill=(255, 255, 250))
    d.polygon([(cx, cy - 3), (cx + 3, cy), (cx, cy + 3), (cx - 3, cy)], fill=(255, 255, 255))
    return im


# --- G: two offset shells with an energy gap --------------------------------
def concept_g():
    im = bg()
    d = ImageDraw.Draw(im)
    cx, cy, r = 64, 62, 42
    halo(im, cx, cy, r, G.GOLD, 2, 14)
    # gold left shell (offset -3)
    d.ellipse([cx - r - 2 - 3, cy - r - 2, cx + 4 - 3, cy + r + 2], fill=INK)
    d.pieslice([cx - r - 3, cy - r, cx + 5 - 3, cy + r], 90, 270, fill=G.GOLD_LO)
    d.pieslice([cx - r, cy - r + 3, cx + 4 - 3, cy + r - 3], 90, 270, fill=G.GOLD)
    d.pieslice([cx - r + 7, cy - r + 10, cx - 6, cy + 6], 90, 270, fill=WARM_HI)
    # cyan right shell (offset +3)
    d.ellipse([cx - 4 + 3, cy - r - 2, cx + r + 2 + 3, cy + r + 2], fill=INK)
    d.pieslice([cx - 5 + 3, cy - r, cx + r + 3, cy + r], 270, 450, fill=G.CYAN_LO)
    d.pieslice([cx - 4 + 3, cy - r + 3, cx + r, cy + r - 3], 270, 450, fill=G.CYAN)
    d.pieslice([cx + 6, cy - r + 10, cx + r - 7, cy + 6], 270, 450, fill=COOL_HI)
    # gap sparks
    for (x, y, s) in [(cx + 1, cy - 16, 2), (cx - 1, cy - 4, 1), (cx + 2, cy + 10, 1), (cx, cy + 20, 1)]:
        d.rectangle([x, y, x + s, y + s], fill=(255, 255, 250))
    # white heart at the seam
    d.polygon([(cx, cy - 4), (cx + 4, cy), (cx, cy + 4), (cx - 4, cy)], fill=(255, 255, 250))
    return im


# --- H: eclipse core, rim lights only ---------------------------------------
def concept_h():
    im = bg()
    d = ImageDraw.Draw(im)
    cx, cy, r = 64, 62, 42
    halo(im, cx, cy, r + 2, G.GOLD, 2, 12)
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(16, 22, 30))
    # rim arcs: gold left, cyan right
    d.arc([cx - r, cy - r, cx + r, cy + r], 95, 265, fill=G.GOLD, width=6)
    d.arc([cx - r, cy - r, cx + r, cy + r], 275, 445, fill=G.CYAN, width=6)
    d.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], 100, 260, fill=WARM_HI, width=2)
    d.arc([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], 280, 440, fill=COOL_HI, width=2)
    # inner facets hint
    d.polygon([(cx, cy), (cx - 10, cy - 8), (cx - 6, cy + 10)], fill=(26, 34, 42))
    d.polygon([(cx, cy), (cx + 10, cy - 8), (cx + 6, cy + 10)], fill=(26, 34, 42))
    # spark
    d.polygon([(cx, cy - 5), (cx + 5, cy), (cx, cy + 5), (cx - 5, cy)], fill=(255, 255, 250))
    return im


for name, fn in [("F_diagonal_gem", concept_f), ("G_split_shells", concept_g), ("H_eclipse_core", concept_h)]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)

names = ["E_split_core", "F_diagonal_gem", "G_split_shells", "H_eclipse_core"]
sheet = Image.new("RGB", (256 * len(names), 256 + 80), (12, 18, 24))
for i, n in enumerate(names):
    big = Image.open(os.path.join(OUT, f"{n}_512.png")).convert("RGB").resize((256, 256), Image.NEAREST)
    small = Image.open(os.path.join(OUT, f"{n}_32.png")).convert("RGB").resize((64, 64), Image.NEAREST)
    sheet.paste(big, (i * 256, 0))
    sheet.paste(small, (i * 256 + 96, 266))
sheet.save(os.path.join(OUT, "sheet_four.png"))
print("sheet saved")
