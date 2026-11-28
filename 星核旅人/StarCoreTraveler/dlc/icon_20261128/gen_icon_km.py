import os, math
from PIL import Image, ImageDraw
import gen_icons as G
import gen_icon_kl as KL

OUT = G.OUT
INK = (9, 14, 20)
WARM_HI = (255, 238, 186)
COOL_HI = (188, 250, 251)


def concept_k2():
    im = KL.bg()
    d = ImageDraw.Draw(im)
    KL.split_core(im, 64, 56, 30, False)
    # deck
    d.rectangle([0, 104, 50, 114], fill=G.STONE)
    d.rectangle([0, 104, 50, 106], fill=G.STONE_HI)
    d.rectangle([82, 104, 128, 114], fill=G.STONE)
    d.rectangle([82, 104, 128, 106], fill=G.STONE_HI)
    # slim pylons
    for x in (14, 106):
        d.rectangle([x, 92, x + 8, 104], fill=G.STONE_LO)
        d.rectangle([x, 92, x + 8, 94], fill=G.STONE_HI)
    # rubble
    d.rectangle([54, 110, 60, 114], fill=G.STONE_LO)
    d.rectangle([74, 111, 80, 114], fill=G.STONE_LO)
    # traveler, slightly bigger, cyan scarf
    x, base = 26, 104
    d.rectangle([x, base - 11, x + 5, base], fill=INK)
    d.rectangle([x + 1, base - 17, x + 5, base - 11], fill=INK)
    d.polygon([(x, base - 11), (x - 7, base - 1), (x + 1, base - 3)], fill=(92, 42, 72))
    d.rectangle([x + 5, base - 12, x + 7, base - 9], fill=G.CYAN)
    return im


def concept_m():
    im = KL.bg()
    d = ImageDraw.Draw(im)
    KL.split_core(im, 64, 50, 34, False)
    # deck
    d.rectangle([0, 108, 128, 116], fill=G.STONE)
    d.rectangle([0, 108, 128, 110], fill=G.STONE_HI)
    # traveler silhouette in front, lower centre, facing the core
    x, base = 56, 108
    d.rectangle([x, base - 14, x + 7, base], fill=INK)          # body
    d.rectangle([x + 1, base - 21, x + 6, base - 14], fill=INK)  # head
    d.polygon([(x, base - 14), (x - 9, base - 2), (x + 1, base - 5)], fill=(92, 42, 72))
    d.rectangle([x + 7, base - 15, x + 9, base - 11], fill=G.CYAN)  # scarf tip
    d.rectangle([x, base - 2, x + 8, base], fill=INK)
    return im


for name, fn in [("K2_core_bridge", concept_k2), ("M_traveler_front", concept_m)]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)

names = ["K_core_bridge_traveler", "K2_core_bridge", "M_traveler_front", "J_zigzag_ring"]
sheet = Image.new("RGB", (256 * len(names), 256 + 80), (12, 18, 24))
for i, n in enumerate(names):
    big = Image.open(os.path.join(OUT, f"{n}_512.png")).convert("RGB").resize((256, 256), Image.NEAREST)
    small = Image.open(os.path.join(OUT, f"{n}_32.png")).convert("RGB").resize((64, 64), Image.NEAREST)
    sheet.paste(big, (i * 256, 0))
    sheet.paste(small, (i * 256 + 96, 266))
sheet.save(os.path.join(OUT, "sheet_km.png"))
print("sheet saved")
