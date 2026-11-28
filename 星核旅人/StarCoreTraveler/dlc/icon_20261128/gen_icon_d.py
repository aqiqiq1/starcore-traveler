import os
from PIL import Image, ImageDraw
import gen_icons as G

OUT = G.OUT


def concept_d():
    im = G.gradient(128)
    d = ImageDraw.Draw(im)
    # low clouds
    for y, w, x in [(94, 44, 8), (100, 28, 90)]:
        d.rectangle([x, y, x + w, y + 2], fill=G.CLOUD)
    # bridge silhouette, one clean gap
    d.rectangle([0, 108, 50, 116], fill=G.STONE)
    d.rectangle([0, 108, 50, 110], fill=G.STONE_HI)
    d.rectangle([78, 108, 128, 116], fill=G.STONE)
    d.rectangle([78, 108, 128, 110], fill=G.STONE_HI)
    d.rectangle([52, 112, 56, 116], fill=G.STONE_LO)
    # split ring
    cx, cy, r = 64, 58, 34
    G.halo(im, cx, cy, 30, G.GOLD, steps=3)
    d.ellipse([cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4], fill=G.INK)
    d.pieslice([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], 90, 270, fill=G.GOLD)
    d.pieslice([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], 270, 450, fill=G.CYAN)
    d.ellipse([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], fill=(18, 26, 32))
    # core inside
    G.halo(im, cx, cy, 14, G.GOLD, steps=2)
    G.core(d, cx, cy, 14, True)
    # traveler on the left deck
    d.rectangle([26, 94, 32, 108], fill=G.INK)
    d.rectangle([28, 88, 32, 94], fill=G.INK)
    d.polygon([(26, 94), (18, 106), (27, 104)], fill=(90, 40, 70))
    return im


for name, fn in [("D_ring_core_bridge", concept_d)]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)

names = ["A2_core_bridge", "D_ring_core_bridge", "B_mirror_eye", "C_traveler_core"]
sheet = Image.new("RGB", (256 * 4, 256 + 80), (12, 18, 24))
for i, n in enumerate(names):
    big = Image.open(os.path.join(OUT, f"{n}_512.png")).convert("RGB").resize((256, 256), Image.NEAREST)
    small = Image.open(os.path.join(OUT, f"{n}_32.png")).convert("RGB").resize((64, 64), Image.NEAREST)
    sheet.paste(big, (i * 256, 0))
    sheet.paste(small, (i * 256 + 96, 266))
sheet.save(os.path.join(OUT, "sheet_4.png"))
print("sheet saved")
