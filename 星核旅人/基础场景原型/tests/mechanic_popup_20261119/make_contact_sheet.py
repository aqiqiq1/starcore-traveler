"""Build the 2026-11-19 mechanic-popup contact sheet.

Run with the approved interpreter:
  D:/minic/envs/2024212971/python.exe make_contact_sheet.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
FONT_PATH = HERE.parent.parent / "assets" / "fonts" / "tutorial_zh.ttf"

SHOTS = [
    ("popup_polarity.png", "1  相性 / 符石 · polarity"),
    ("popup_core_carry.png", "2  运核入仓 · core_carry"),
    ("popup_relay_link.png", "3  联动仓解锁 · relay_link"),
    ("popup_float_platform.png", "4  浮地装置 · float_platform"),
    ("popup_guard_page1.png", "5  守卫吸附 · 无效伤害（1/2）"),
    ("popup_guard_page2.png", "6  守卫有效伤害（2/2）"),
    ("popup_guard_after_cine_annotated.png", "残响结束后 · 守卫教程（状态图）"),
    ("popup_skip_hold.png", "长按 0.5s · 共享 SkipHoldBar"),
    ("popup_missing_demo.png", "降级  素材缺失时文字占满"),
]

TILE_W, TILE_H = 480, 270
LABEL_H = 24
GAP = 10
HEADER_H = 40
COLS = 2
ROWS = (len(SHOTS) + COLS - 1) // COLS

WIDTH = COLS * TILE_W + (COLS + 1) * GAP
HEIGHT = HEADER_H + ROWS * (TILE_H + LABEL_H) + (ROWS + 1) * GAP
BG = (8, 14, 18)
LABEL_BG = (14, 30, 36)
GOLD = (244, 205, 99)
MUTED = (164, 179, 190)


def main() -> None:
    sheet = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(sheet)
    header_font = ImageFont.truetype(str(FONT_PATH), 20)
    label_font = ImageFont.truetype(str(FONT_PATH), 16)
    small_font = ImageFont.truetype(str(FONT_PATH), 12)

    draw.text(
        (GAP, 10),
        "机制演示弹窗 · 640×360 打开态 · 2026-11-19",
        font=header_font,
        fill=GOLD,
    )
    draw.text(
        (WIDTH - 320, 16),
        "一关借力已并入相性/符石",
        font=small_font,
        fill=MUTED,
    )

    for index, (file_name, label) in enumerate(SHOTS):
        row = index // COLS
        col = index % COLS
        x = GAP + col * (TILE_W + GAP)
        y = HEADER_H + GAP + row * (TILE_H + LABEL_H + GAP)
        draw.rectangle((x, y, x + TILE_W, y + LABEL_H), fill=LABEL_BG)
        draw.text((x + 6, y + 3), label, font=label_font, fill=GOLD)
        shot_path = HERE / file_name
        if not shot_path.exists():
            draw.rectangle((x, y + LABEL_H, x + TILE_W, y + LABEL_H + TILE_H), fill=(40, 0, 0))
            draw.text((x + 8, y + LABEL_H + 8), "MISSING", font=label_font, fill=(255, 120, 120))
            continue
        with Image.open(shot_path) as shot:
            shot = shot.convert("RGB")
            if shot.size != (640, 360):
                shot = shot.resize((640, 360), Image.NEAREST)
            shot = shot.resize((TILE_W, TILE_H), Image.LANCZOS)
        sheet.paste(shot, (x, y + LABEL_H))

    out_path = HERE / "contact_sheet_20261119.png"
    sheet.save(out_path)
    print(f"wrote {out_path} {sheet.size}")


if __name__ == "__main__":
    main()
