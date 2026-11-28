import os
from PIL import Image

SRC = "assets/icon/concepts/J_zigzag_ring_128.png"
OUT = "assets/icon"
os.makedirs(OUT, exist_ok=True)

base = Image.open(SRC).convert("RGB")
for size in [1024, 512, 256, 128, 64, 32]:
    base.resize((size, size), Image.NEAREST).save(os.path.join(OUT, f"icon_{size}.png"))
# Windows .ico with the usual sizes
base.resize((256, 256), Image.NEAREST).save(
    os.path.join(OUT, "icon.ico"),
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
print("icons written", sorted(os.listdir(OUT)))
