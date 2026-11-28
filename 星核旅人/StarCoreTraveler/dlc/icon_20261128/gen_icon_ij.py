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
        c = tuple(int((10, 18, 28)[i] + ((20, 40, 50)[i] - (10, 18, 28)[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return im


def halo(im, cx, cy, r, color, steps=3, alpha=20):
    for i in range(steps, 0, -1):
        rr = r + i * 5
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (int(alpha / i),))
        im.alpha_composite(layer)


def seam_points(cx, cy, r):
    # zigzag from top to bottom, x relative to cx
    ys = [-r + 2, -r * 0.55, -r * 0.2, r * 0.15, r * 0.5, r - 2]
    xs = [0, -3, 2, -2, 3, 0]
    return [(cx + xs[i], cy + ys[i]) for i in range(len(ys))]


def concept_i(with_ring=False):
    im = bg()
    d = ImageDraw.Draw(im)
    cx, cy, r = 64, 62, 40
    halo(im, cx, cy, r, G.GOLD, 3, 16)
    if with_ring:
        rr = r + 10
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 95, 265, fill=(120, 96, 44), width=3)
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 275, 445, fill=(38, 92, 98), width=3)
    # dark rim
    d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], fill=INK)
    # gold base
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=G.GOLD)
    # cyan right side bounded by the zigzag seam and the right arc
    seam = seam_points(cx, cy, r)
    right_arc = []
    for deg in range(-62, 63, 6):
        a = math.radians(deg)
        right_arc.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    poly = seam + list(reversed(right_arc))
    d.polygon(poly, fill=G.CYAN)
    # seam gap
    for i in range(len(seam) - 1):
        d.line([seam[i], seam[i + 1]], fill=INK, width=2)
    # facets
    d.polygon([(cx - 22, cy - 24), (cx - 6, cy - 30), (cx - 4, cy - 6), (cx - 20, cy - 2)], fill=WARM_HI)
    d.polygon([(cx - 26, cy + 4), (cx - 8, cy + 8), (cx - 10, cy + 30), (cx - 24, cy + 24)], fill=(150, 106, 36))
    d.polygon([(cx + 10, cy - 26), (cx + 26, cy - 18), (cx + 22, cy + 2), (cx + 8, cy - 2)], fill=COOL_HI)
    d.polygon([(cx + 8, cy + 6), (cx + 24, cy + 2), (cx + 20, cy + 26), (cx + 6, cy + 28)], fill=G.CYAN_LO)
    # rim light on each side
    d.arc([cx - r, cy - r, cx + r, cy + r], 120, 240, fill=(255, 246, 214), width=2)
    d.arc([cx - r, cy - r, cx + r, cy + r], 300, 420, fill=(220, 255, 255), width=2)
    # central star
    d.polygon([(cx, cy - 7), (cx + 3, cy - 3), (cx + 7, cy), (cx + 3, cy + 3),
               (cx, cy + 7), (cx - 3, cy + 3), (cx - 7, cy), (cx - 3, cy - 3)], fill=(255, 255, 250))
    return im


for name, fn in [("I_zigzag_core", lambda: concept_i(False)), ("J_zigzag_ring", lambda: concept_i(True))]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)

names = ["E_split_core", "I_zigzag_core", "J_zigzag_ring", "H_eclipse_core"]
sheet = Image.new("RGB", (256 * len(names), 256 + 80), (12, 18, 24))
for i, n in enumerate(names):
    big = Image.open(os.path.join(OUT, f"{n}_512.png")).convert("RGB").resize((256, 256), Image.NEAREST)
    small = Image.open(os.path.join(OUT, f"{n}_32.png")).convert("RGB").resize((64, 64), Image.NEAREST)
    sheet.paste(big, (i * 256, 0))
    sheet.paste(small, (i * 256 + 96, 266))
sheet.save(os.path.join(OUT, "sheet_zig.png"))
print("sheet saved")
