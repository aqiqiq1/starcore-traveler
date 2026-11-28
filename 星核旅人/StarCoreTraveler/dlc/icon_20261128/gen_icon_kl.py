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
        c = tuple(int((10, 18, 28)[i] + ((26, 52, 64)[i] - (10, 18, 28)[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return im


def halo(im, cx, cy, r, color, steps=3, alpha=18):
    for i in range(steps, 0, -1):
        rr = r + i * 4
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=color + (int(alpha / i),))
        im.alpha_composite(layer)


def zigzag_seam(cx, cy, r):
    ys = [-r + 2, -r * 0.55, -r * 0.2, r * 0.15, r * 0.5, r - 2]
    xs = [0, -2, 2, -1, 2, 0]
    return [(cx + xs[i], cy + ys[i]) for i in range(len(ys))]


def split_core(im, cx, cy, r, with_ring=False):
    d = ImageDraw.Draw(im)
    halo(im, cx, cy, r, G.GOLD, 3, 16)
    if with_ring:
        rr = r + 7
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 95, 265, fill=(128, 100, 44), width=2)
        d.arc([cx - rr, cy - rr, cx + rr, cy + rr], 275, 445, fill=(40, 96, 102), width=2)
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=INK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=G.GOLD)
    seam = zigzag_seam(cx, cy, r)
    right_arc = []
    for deg in range(-62, 63, 6):
        a = math.radians(deg)
        right_arc.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(seam + list(reversed(right_arc)), fill=G.CYAN)
    for i in range(len(seam) - 1):
        d.line([seam[i], seam[i + 1]], fill=INK, width=1)
    d.polygon([(cx - r + 6, cy - r + 10), (cx - 4, cy - r + 5), (cx - 3, cy - 3), (cx - r + 8, cy + 2)], fill=WARM_HI)
    d.polygon([(cx + 4, cy - r + 5), (cx + r - 5, cy - r + 9), (cx + r - 6, cy + 2), (cx + 3, cy - 3)], fill=COOL_HI)
    d.polygon([(cx - r + 8, cy + 4), (cx - 4, cy + 3), (cx - 4, cy + r - 5), (cx - r + 10, cy + r - 9)], fill=(148, 104, 34))
    d.polygon([(cx + 4, cy + 4), (cx + r - 6, cy + 3), (cx + r - 8, cy + r - 8), (cx + 3, cy + r - 5)], fill=G.CYAN_LO)
    d.polygon([(cx, cy - 4), (cx + 2, cy - 2), (cx + 4, cy), (cx + 2, cy + 2),
               (cx, cy + 4), (cx - 2, cy + 2), (cx - 4, cy), (cx - 2, cy - 2)], fill=(255, 255, 250))


def bridge(d):
    # deck with a clear gap under the core
    d.rectangle([0, 106, 48, 114], fill=G.STONE)
    d.rectangle([0, 106, 48, 108], fill=G.STONE_HI)
    d.rectangle([84, 106, 128, 114], fill=G.STONE)
    d.rectangle([84, 106, 128, 108], fill=G.STONE_HI)
    d.rectangle([12, 94, 22, 106], fill=G.STONE_HI)
    d.rectangle([106, 94, 116, 106], fill=G.STONE_HI)
    d.rectangle([52, 110, 58, 114], fill=G.STONE_LO)
    d.rectangle([74, 111, 80, 114], fill=G.STONE_LO)


def traveler(d, x, base_y):
    # 8 x 16 silhouette, cape to the left, facing right
    d.rectangle([x, base_y - 10, x + 4, base_y], fill=INK)          # body
    d.rectangle([x + 1, base_y - 15, x + 4, base_y - 10], fill=INK)  # head
    d.polygon([(x, base_y - 10), (x - 6, base_y - 1), (x + 1, base_y - 3)], fill=(92, 42, 72))
    d.rectangle([x, base_y - 2, x + 5, base_y], fill=INK)


def concept_k(with_ring=False):
    im = bg()
    d = ImageDraw.Draw(im)
    # low cloud band
    d.rectangle([6, 96, 50, 98], fill=(92, 124, 134))
    d.rectangle([88, 92, 122, 94], fill=(92, 124, 134))
    split_core(im, 64, 52, 24, with_ring)
    bridge(d)
    traveler(d, 30, 106)
    return im


for name, fn in [("K_core_bridge_traveler", lambda: concept_k(False)),
                 ("L_core_bridge_traveler_ring", lambda: concept_k(True))]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)

names = ["J_zigzag_ring", "K_core_bridge_traveler", "L_core_bridge_traveler_ring"]
sheet = Image.new("RGB", (256 * len(names), 256 + 80), (12, 18, 24))
for i, n in enumerate(names):
    big = Image.open(os.path.join(OUT, f"{n}_512.png")).convert("RGB").resize((256, 256), Image.NEAREST)
    small = Image.open(os.path.join(OUT, f"{n}_32.png")).convert("RGB").resize((64, 64), Image.NEAREST)
    sheet.paste(big, (i * 256, 0))
    sheet.paste(small, (i * 256 + 96, 266))
sheet.save(os.path.join(OUT, "sheet_kl.png"))
print("sheet saved")
