"""Annotate the L2 relay trigger map over the real x=400 screenshot.

Run:
  D:/minic/envs/2024212971/python.exe annotate_relay_trigger.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT_PATH = HERE.parent.parent / "assets" / "fonts" / "tutorial_zh.ttf"
RAW = HERE / "relay_trigger_map_raw.png"
OUT = HERE / "relay_trigger_map.png"

# World-to-screen at the captured player x=400 (camera centre x=400):
# screen_x = world_x - 400 + 320.
RELAY_X = 352 - 400 + 320   # 272
PLAYER_X = 400 - 400 + 320  # 320
TRIGGER_X = 420 - 400 + 320 # 340
ROOF_X = 464 - 400 + 320    # 384


def main() -> None:
    base = Image.open(RAW).convert("RGB")
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    title_font = ImageFont.truetype(str(FONT_PATH), 13)
    small = ImageFont.truetype(str(FONT_PATH), 11)

    draw.rectangle((0, 40, base.width, 64), fill=(8, 14, 18, 210))
    draw.text((8, 43), "L2 relay trigger map · post-relay", font=title_font, fill=(244, 205, 99))

    def line(x: int, color: tuple[int, int, int], label: str, lx: int, ly: int) -> None:
        draw.line((x, 100, x, 320), fill=(*color, 230), width=2)
        width = int(draw.textlength(label, font=small))
        draw.rectangle((lx - 3, ly - 2, lx + width + 3, ly + 13), fill=(8, 14, 18, 215))
        draw.text((lx, ly), label, font=small, fill=color)

    line(RELAY_X, (164, 179, 190), "RelayBay 352", 190, 104)
    line(TRIGGER_X, (244, 205, 99), "trigger 420", 296, 104)
    line(ROOF_X, (95, 225, 230), "Roof 464–720", 392, 104)

    # Player marker.
    draw.line((PLAYER_X, 292, PLAYER_X, 318), fill=(244, 205, 99, 230), width=2)
    draw.text((258, 270), "player 400", font=small, fill=(244, 205, 99))
    draw.line((PLAYER_X, 270, PLAYER_X, 256), fill=(244, 205, 99, 230), width=1)

    # Bottom note: no popup at x=400; the x=420 request is the first one.
    draw.rectangle((0, 336, base.width, base.height), fill=(8, 14, 18, 210))
    draw.text(
        (8, 339),
        "x=400 no popup · x=420 opens before roof x=464 · test PASS",
        font=small,
        fill=(164, 179, 190),
    )

    result = Image.alpha_composite(base.convert("RGBA"), overlay).convert("RGB")
    result.save(OUT)
    print(f"wrote {OUT} {result.size}")


if __name__ == "__main__":
    main()
