import os
from PIL import Image, ImageDraw
import gen_icons as G

OUT = G.OUT
os.makedirs(OUT, exist_ok=True)

BG_TOP = (12, 22, 32)
BG_BOT = (22, 44, 54)
GOLD_HI2 = (255, 236, 176)
CYAN_HI2 = (176, 248, 249)
INK = (10, 16, 22)


def bg(size=128):
    im = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):
        t = y / (size - 1)
        c = tuple(int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)
    return im


def half_halo(im, cx, cy, r, color, left_half):
    for i in range(4, 0, -1):
        rr = r + i * 4
        layer = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        box = [cx - rr, cy - rr, cx + rr, cy + rr]
        start, end = (90, 270) if left_half else (270, 450)
        ld.pieslice(box, start, end, fill=color + (int(26 / i),))
        im.alpha_composite(layer)


def split_core(im, cx, cy, r):
    d = ImageDraw.Draw(im)
    half_halo(im, cx, cy, r + 4, G.GOLD, True)
    half_halo(im, cx, cy, r + 4, G.CYAN, False)
    # outline
    d.ellipse([cx - r - 2, cy - r - 2, cx + r + 2, cy + r + 2], fill=INK)
    # base halves
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 90, 270, fill=G.GOLD)
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 270, 450, fill=G.CYAN)
    # facet: top-left light (gold side), bottom-left shade
    d.polygon([(cx - r + 3, cy - 2), (cx - 2, cy - r + 3), (cx - r + 6, cy - r + 10),
               (cx - r + 8, cy - 8)], fill=GOLD_HI2)
    d.polygon([(cx - 3, cy + r - 6), (cx - r + 4, cy + 6), (cx - r + 10, cy + r - 12),
               (cx - 8, cy + r - 4)], fill=G.GOLD_LO)
    # facet: top-right light (cyan side), bottom-right shade
    d.polygon([(cx + 2, cy - r + 3), (cx + r - 3, cy - 2), (cx + r - 8, cy - 8),
               (cx + r - 6, cy - r + 10)], fill=CYAN_HI2)
    d.polygon([(cx + 3, cy + r - 6), (cx + r - 4, cy + 6), (cx + r - 10, cy + r - 12),
               (cx + 8, cy + r - 4)], fill=G.CYAN_LO)
    # center seam + white core light
    d.rectangle([cx - 1, cy - r + 4, cx, cy + r - 5], fill=INK)
    d.polygon([(cx, cy - 5), (cx + 4, cy), (cx, cy + 5), (cx - 4, cy)], fill=G.WHITE)
    d.polygon([(cx, cy - 3), (cx + 2, cy), (cx, cy + 3), (cx - 2, cy)], fill=(255, 255, 250))
    # small glint on each half
    d.rectangle([cx - r + 9, cy - r + 9, cx - r + 12, cy - r + 12], fill=(255, 252, 240))
    d.rectangle([cx + r - 12, cy - r + 12, cx + r - 10, cy - r + 14], fill=(255, 255, 255))


def concept_e():
    im = bg(128)
    split_core(im, 64, 62, 42)
    return im


base = concept_e()
base.convert("RGB").save(os.path.join(OUT, "E_split_core_128.png"))
base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, "E_split_core_512.png"))
base.convert("RGB").resize((64, 64), Image.NEAREST).save(os.path.join(OUT, "E_split_core_64.png"))
base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, "E_split_core_32.png"))
print("saved E_split_core")
