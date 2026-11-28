import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.abspath(os.path.join(here, "..", ".."))
os.chdir(root)
sys.path.insert(0, here)

from PIL import Image, ImageDraw  # noqa: E402
import gen_icons as G  # noqa: E402
import gen_icon_kl as KL  # noqa: E402

OUT = G.OUT
INK = (9, 14, 20)


def concept_m2():
    im = KL.bg()
    d = ImageDraw.Draw(im)
    KL.split_core(im, 64, 48, 30, False)
    # broken bridge with the gap under the core
    d.rectangle([0, 106, 52, 116], fill=G.STONE)
    d.rectangle([0, 106, 52, 108], fill=G.STONE_HI)
    d.rectangle([80, 106, 128, 116], fill=G.STONE)
    d.rectangle([80, 106, 128, 108], fill=G.STONE_HI)
    d.rectangle([56, 112, 62, 116], fill=G.STONE_LO)
    d.rectangle([72, 113, 78, 116], fill=G.STONE_LO)
    # traveler at the left edge of the gap, facing right
    x, base = 44, 106
    d.rectangle([x, base - 13, x + 5, base], fill=INK)
    d.rectangle([x + 1, base - 20, x + 5, base - 13], fill=INK)
    d.polygon([(x, base - 13), (x - 7, base - 2), (x + 1, base - 5)], fill=(92, 42, 72))
    d.rectangle([x + 5, base - 14, x + 7, base - 10], fill=G.CYAN)
    return im


base = concept_m2()
base.convert("RGB").save(os.path.join(OUT, "M2_traveler_gap_128.png"))
base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, "M2_traveler_gap_512.png"))
base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, "M2_traveler_gap_32.png"))

names = ["K2_core_bridge", "M_traveler_front", "M2_traveler_gap", "J_zigzag_ring"]
sheet = Image.new("RGB", (256 * len(names), 256 + 80), (12, 18, 24))
for i, n in enumerate(names):
    big = Image.open(os.path.join(OUT, f"{n}_512.png")).convert("RGB").resize((256, 256), Image.NEAREST)
    small = Image.open(os.path.join(OUT, f"{n}_32.png")).convert("RGB").resize((64, 64), Image.NEAREST)
    sheet.paste(big, (i * 256, 0))
    sheet.paste(small, (i * 256 + 96, 266))
sheet.save(os.path.join(OUT, "sheet_m2.png"))
print("saved M2 and sheet")
