import os
from PIL import Image, ImageDraw
import sys
sys.path.insert(0, os.path.dirname(__file__))
import gen_icons as G

OUT = G.OUT


def concept_a2():
    im = G.gradient(128)
    d = ImageDraw.Draw(im)
    # low cloud bands
    for y, w, x in [(92, 46, 6), (98, 30, 88)]:
        d.rectangle([x, y, x + w, y + 2], fill=G.CLOUD)
        d.rectangle([x + 4, y - 2, x + w - 6, y], fill=G.CLOUD_HI)
    # bridge deck with a clear gap
    d.rectangle([0, 106, 54, 114], fill=G.STONE)
    d.rectangle([0, 106, 54, 108], fill=G.STONE_HI)
    d.rectangle([74, 106, 128, 114], fill=G.STONE)
    d.rectangle([74, 106, 128, 108], fill=G.STONE_HI)
    # pylons
    d.rectangle([10, 94, 20, 106], fill=G.STONE_HI)
    d.rectangle([108, 94, 118, 106], fill=G.STONE_HI)
    # rubble
    d.rectangle([56, 110, 60, 114], fill=G.STONE_LO)
    d.rectangle([68, 111, 73, 114], fill=G.STONE_LO)
    # core
    G.halo(im, 64, 60, 22, G.GOLD)
    G.core(d, 64, 60, 20, True)
    # traveler silhouette, left deck
    d.rectangle([36, 90, 43, 106], fill=G.INK)         # body
    d.rectangle([38, 83, 43, 90], fill=G.INK)          # head
    d.polygon([(36, 90), (27, 104), (37, 101)], fill=(90, 40, 70))  # cape
    d.rectangle([35, 104, 44, 106], fill=G.INK)        # feet
    return im


for name, fn in [("A2_core_bridge", concept_a2)]:
    base = fn()
    base.convert("RGB").save(os.path.join(OUT, f"{name}_128.png"))
    base.convert("RGB").resize((512, 512), Image.NEAREST).save(os.path.join(OUT, f"{name}_512.png"))
    base.convert("RGB").resize((32, 32), Image.NEAREST).save(os.path.join(OUT, f"{name}_32.png"))
    print("saved", name)
