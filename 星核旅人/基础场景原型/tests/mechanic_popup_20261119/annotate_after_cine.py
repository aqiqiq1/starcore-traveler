"""Add a small state caption to the post-echo guard popup screenshot.

The raw 640x360 capture stays untouched as popup_guard_after_cine.png; this
derived copy only adds a bottom caption with the placement/stage facts from
popup_guard_after_cine_state.txt.

Run:
  D:/minic/envs/2024212971/python.exe annotate_after_cine.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT_PATH = HERE.parent.parent / "assets" / "fonts" / "tutorial_zh.ttf"
RAW = HERE / "popup_guard_after_cine.png"
OUT = HERE / "popup_guard_after_cine_annotated.png"

CAPTION = (
    "残响结束 · player=(1987,320) · stage=ARENA · "
    "guard=GRAVITY_CHARGE(0.000) · slam=0 · 1/2"
)


def main() -> None:
    image = Image.open(RAW).convert("RGB")
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(str(FONT_PATH), 11)
    draw.rectangle((0, 342, image.width, image.height), fill=(8, 14, 18))
    draw.text((8, 344), CAPTION, font=font, fill=(164, 179, 190))
    image.save(OUT)
    print(f"wrote {OUT} {image.size}")


if __name__ == "__main__":
    main()
