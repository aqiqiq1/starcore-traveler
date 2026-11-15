"""Compact review sheet for the formal bridge_stone_v1 source.

This is an art review document, not an in-engine capture.
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
EX = os.path.join(HERE, "examples")
COL = os.path.abspath(os.path.join(HERE, "..", "columns"))
OUT = os.path.join(HERE, "contact_sheet.png")

W, H = 1240, 1320
BG = (29, 30, 35, 255)
INK = (226, 220, 211, 255)
MUT = (156, 151, 143, 255)
ACC = (198, 168, 122, 255)
LINE = (66, 68, 76, 255)

FONT = "C:/Windows/Fonts/msyh.ttc"
try:
    ft = ImageFont.truetype(FONT, 26)
    fh = ImageFont.truetype(FONT, 17)
    fl = ImageFont.truetype(FONT, 13)
    fs = ImageFont.truetype(FONT, 11)
except OSError:
    ft = fh = fl = fs = ImageFont.load_default()

P = {
    "TOPHI": (198, 187, 174), "TOP": (186, 175, 163), "LIGHT2": (172, 160, 151),
    "LIGHT": (159, 146, 138), "MID2": (147, 132, 127), "MID": (136, 122, 120),
    "MIDD": (124, 110, 109), "BEAR": (106, 94, 97), "BEAR2": (94, 84, 88),
    "DEEP": (76, 67, 73),
}


def up(im, s):
    return im.resize((im.width * s, im.height * s), Image.NEAREST)


def place(sheet, im, x, y, label, note=""):
    sheet.alpha_composite(im, (x, y))
    d = ImageDraw.Draw(sheet)
    d.text((x, y - 19), label, font=fl, fill=INK)
    if note:
        d.text((x + d.textlength(label, font=fl) + 7, y - 18), note, font=fs, fill=MUT)


def main():
    sheet = Image.new("RGBA", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((24, 16), "桥头石造地面 · 正式素材与结构暗部", font=ft, fill=INK)
    d.text((24, 50), "SOURCE REVIEW — 1:1 原生像素 / 2× 局部 / 仅美术检查，不是实机截图",
           font=fs, fill=MUT)

    # 01 native
    d.text((24, 78), "01  原生尺寸（1 source px = 1 world unit）", font=fh, fill=ACC)
    high = Image.open(os.path.join(EX, "high_336x144.png")).convert("RGBA")
    long = Image.open(os.path.join(EX, "long_512x64.png")).convert("RGBA")
    place(sheet, high, 24, 124, "高台 336×144", "broken right")
    place(sheet, long, 392, 124, "长地基 512×64", "solid both")

    # tone ladder
    lx, ly = 930, 124
    d.text((lx, 96), "结构明暗是离散石阶", font=fl, fill=INK)
    d.text((lx, 110), "不是透明黑蒙版 / 不是全局 modulate", font=fs, fill=MUT)
    ladder = ["TOPHI", "TOP", "LIGHT2", "LIGHT", "MID2", "MID", "MIDD", "BEAR", "BEAR2", "DEEP"]
    for i, name in enumerate(ladder):
        y = ly + 10 + i * 16
        d.rectangle([lx, y, lx + 24, y + 12], fill=P[name] + (255,))
        d.text((lx + 32, y), name, font=fs, fill=MUT)

    # 02 shadow / parts
    d.text((24, 300), "02  2× 结构明暗与部件", font=fh, fill=ACC)
    place(sheet, up(high.crop((0, 0, 168, 144)), 2), 24, 346,
          "路面 / 檐下阴影 / 上亮下暗", "2×")
    place(sheet, up(high.crop((272, 0, 336, 144)), 2), 376, 346,
          "高台右断端", "2×")
    place(sheet, up(Image.open(os.path.join(EX, "beam_56x24.png")).convert("RGBA"), 4),
          520, 366, "梁 56×24（上亮下暗+梁底）", "4×")
    place(sheet, up(Image.open(os.path.join(EX, "beam_56x8.png")).convert("RGBA"), 4),
          520, 516, "薄梁 56×8（原生薄梁）", "4×")
    place(sheet, up(Image.open(os.path.join(EX, "pier_8x36.png")).convert("RGBA"), 8),
          780, 346, "支承 8×36", "8×")
    place(sheet, up(Image.open(os.path.join(EX, "pier_16x36.png")).convert("RGBA"), 4),
          870, 346, "支承 16×36", "4×")
    d.text((24, 640), "梁底/支承背部、断口内芯、柱脚接触各自有实色暗部；行走面顶边仍保持可读。",
           font=fs, fill=MUT)

    # explanatory panel in the otherwise empty right column
    px, py = 960, 400
    d.text((px, py), "结构暗部怎么来", font=fh, fill=ACC)
    lines = [
        "· 路面：TOP / TOPHI，不过白",
        "· 檐下：2 px DEEP + DARK，实色窄阴影",
        "· 承重：MID2 → MID → MIDD → BEAR → BEAR2",
        "  离散石层，不做透明黑罩",
        "· 局部：少量 LIGHT / LIT 受光石块",
        "· 底缘：BEAR2 / DEEP，水平接地",
        "· 断口：顶面以下 1–4 px 退让",
        "  最上行始终满宽，无内部空洞",
        "· 支承：左亮右暗 + 横向鼓石缝",
        "· 不改变 DS03 背景与柱子上部像素",
    ]
    for i, line in enumerate(lines):
        d.text((px, py + 30 + i * 18), line, font=fs, fill=MUT)

    # 03 broken ends / minimum
    d.text((24, 660), "03  断端与最小尺寸", font=fh, fill=ACC)
    place(sheet, up(Image.open(os.path.join(EX, "beam_56x24_broken.png")).convert("RGBA"), 4),
          24, 706, "梁 56×24 右断", "4×")
    place(sheet, up(Image.open(os.path.join(EX, "beam_56x8_broken.png")).convert("RGBA"), 8),
          270, 706, "薄梁 56×8 右断", "8×")
    place(sheet, up(Image.open(os.path.join(EX, "pier_8x36_broken.png")).convert("RGBA"), 8),
          730, 706, "支承 8×36 右断", "8×")
    place(sheet, up(Image.open(os.path.join(EX, "min_ground_32x32.png")).convert("RGBA"), 4),
          820, 706, "地面 32×32 两端断", "4×")
    d.text((24, 1002), "断端只退让顶面以下 1–4 px；最上行始终满宽；无内部空洞。",
           font=fs, fill=MUT)

    # 04 columns
    d.text((24, 1026), "04  柱脚：方形平底（2× 全高 / 6× 底部）", font=fh, fill=ACC)
    cols = [
        ("doric_column_tall_basesquare.png", "高柱", 108),
        ("doric_column_broken_basesquare.png", "断柱", 82),
        ("doric_column_base_basesquare.png", "柱座", 24),
    ]
    baseline = 1272
    x = 24
    for f, label, h in cols:
        im = Image.open(os.path.join(COL, f)).convert("RGBA")
        big = up(im, 2)
        sheet.alpha_composite(big, (x, baseline - big.height))
        d.text((x, baseline + 6), f"{label} 2×", font=fs, fill=INK)
        x += big.width + 12
    # 6x contact detail (the three share the same 9-row plinth)
    x = 400
    for f, label, h in cols[:2]:
        im = Image.open(os.path.join(COL, f)).convert("RGBA")
        big = up(im.crop((0, h - 12, 52, h)), 6)
        sheet.alpha_composite(big, (x, 1174))
        d.text((x, 1156), f"{label} 底部 6×", font=fs, fill=INK)
        x += big.width + 18
    d.text((400, 1292), "三张柱脚共用同一 9 行方形平底；改动行 99–107 / 73–81 / 15–23，上部逐像素未动。",
           font=fs, fill=MUT)
    d.text((24, 1300), "透明处按深灰背景显示。",
           font=fs, fill=MUT)

    sheet.save(OUT)
    print("saved", OUT, sheet.size)


if __name__ == "__main__":
    main()
