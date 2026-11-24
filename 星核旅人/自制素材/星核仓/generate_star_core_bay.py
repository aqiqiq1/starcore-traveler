#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
星核旅人 · 星核仓首版素材生成器（32×32 侧视像素，分层）
------------------------------------------------------------
纯程序化像素绘制，不使用外部生成服务、不下载素材、不修改原素材。

组成：
  star_core_bay_base.png   32×32 透明底，白色石质底座（后层）
  star_core_bay_glass.png  32×32 同原点，浅青半圆钟形玻璃罩（前层）
  star_core_bay_empty.png  32×32 空仓组合图（base + glass，供直接拖用）

放置约定：
  - 三张图都是 32×32，中心原点一致；底座中心线与玻璃中心线均为 x=15.5。
  - 既有 16×16 紫色星核在 Godot 中放在 (0,0)，占据图像 x=8..23、y=8..23。
  - 底座从图像 y=24 开始，星核底边 y=23，二者不重叠。
  - 玻璃罩内腔在星核所在 16×16 矩形内完全透明，不遮星核。
  - 玻璃罩上部为半圆帽，向下接短直壁到 y=24；32px 内若只用正半圆，
    16px 星核放不下，故用钟形玻璃（半圆帽+短直壁），不缩星核、不改底座。
  - 金色小符文画在底座正面；锁定小标识由 Godot 组件代码绘制，不烘焙进 PNG。

运行（项目指定环境）:
    D:\\minic\\envs\\2024212971\\python.exe generate_star_core_bay.py

输出：
    基础场景原型/assets/star_core_bay/*.png
    本目录同名备份、manifest.json、star_core_bay_review.png
"""

from __future__ import annotations

import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parents[1]
PROJECT_ASSET_DIR = PROJECT_ROOT / "基础场景原型" / "assets" / "star_core_bay"
STAR_CORE_LOCKED = PROJECT_ROOT / "基础场景原型" / "assets" / "star_core" / "star_core_locked.png"

SIZE = 32
CENTER_X = 15.5
CENTER_Y = 16.0
OUTER_RADIUS = 15.0
INNER_RADIUS = 13.0
PEDESTAL_TOP = 24
CORE_RECT = (8, 8, 24, 24)  # x0, y0, x1, y1 (exclusive)

# --- 底座：白/暖白石材 + 灰蓝阴影，不用深色底座 ---
BASE_OUTLINE = (74, 92, 104, 255)       # #4a5c68 灰蓝轮廓
BASE_OUTLINE_DARK = (55, 72, 84, 255)  # #374854
BASE_TOP_HIGHLIGHT = (255, 255, 249, 255)
BASE_TOP_LIGHT = (245, 247, 240, 255)
BASE_WHITE = (238, 242, 237, 255)
BASE_BODY_LIGHT = (226, 233, 230, 255)
BASE_BODY = (213, 223, 222, 255)
BASE_BODY_MID = (190, 204, 207, 255)
BASE_SHADOW = (158, 176, 184, 255)
BASE_SHADOW_DEEP = (121, 143, 155, 255)
BASE_CONTACT = (137, 158, 170, 255)
BASE_FOOT_LIGHT = (231, 236, 231, 255)
BASE_FOOT = (187, 202, 207, 255)
BASE_FOOT_SHADOW = (144, 164, 174, 255)
BASE_SEAM = (173, 190, 196, 255)

GOLD = (218, 176, 86, 255)        # #dab056
GOLD_LIGHT = (247, 221, 144, 255) # #f7dd90
GOLD_DARK = (160, 121, 48, 255)   # #a07930
GOLD_DIM = (186, 150, 72, 255)

# --- 玻璃：浅青边缘、少量白反光、内部全透明 ---
GLASS_PALE = (207, 247, 249, 220)   # #cff7f9
GLASS_OUTER = (172, 234, 239, 205)  # #aceeef
GLASS_MID = (126, 205, 214, 175)    # #7ecdd6
GLASS_DEEP = (79, 152, 165, 150)    # #4f98a5
GLASS_SHADOW = (49, 105, 120, 105)  # #316978
GLASS_GLINT = (255, 255, 255, 235)
GLASS_GLINT_SOFT = (255, 255, 255, 150)
GLASS_WEAK = (255, 255, 255, 48)
GLASS_WEAK_CYAN = (145, 230, 235, 38)
GLASS_SEAL = (170, 232, 238, 105)
GLASS_SEAL_LIGHT = (212, 248, 250, 80)

FONT_CN = "C:/Windows/Fonts/msyh.ttc"
FONT_CN_BOLD = "C:/Windows/Fonts/msyhbd.ttc"
FONT_MONO = "C:/Windows/Fonts/consola.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


def sha256_rgba(image: Image.Image) -> str:
    return hashlib.sha256(image.convert("RGBA").tobytes()).hexdigest()


def put(image: Image.Image, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        image.putpixel((x, y), color)


def fill(image: Image.Image, x0: int, y0: int, x1: int, y1: int,
         color: tuple[int, int, int, int]) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(image, x, y, color)


def draw_base() -> Image.Image:
    """白色石质底座，图像 y=24..31；y<24 必须完全透明。"""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # 顶面：y=24。顶板加宽到 x=2..29，让玻璃短直壁落在石板上；
    # 核心下方留一道接触阴影，但核心像素不进入这一行。
    fill(image, 2, 24, 29, 24, BASE_TOP_LIGHT)
    fill(image, 3, 24, 28, 24, BASE_TOP_HIGHLIGHT)
    fill(image, 8, 24, 23, 24, BASE_CONTACT)
    put(image, 2, 24, BASE_SHADOW_DEEP)
    put(image, 29, 24, BASE_SHADOW_DEEP)

    # 顶沿：y=25..26，厚边与下方主体形成台阶。
    fill(image, 2, 25, 29, 25, BASE_TOP_LIGHT)
    put(image, 2, 25, BASE_OUTLINE)
    put(image, 29, 25, BASE_OUTLINE)
    fill(image, 9, 25, 22, 25, BASE_BODY_MID)  # 核心座位的浅凹槽
    put(image, 3, 25, BASE_TOP_HIGHLIGHT)
    put(image, 28, 25, BASE_SHADOW)

    fill(image, 3, 26, 28, 26, BASE_BODY_MID)  # 顶板下的第一道灰蓝阴影
    put(image, 3, 26, BASE_OUTLINE)
    put(image, 28, 26, BASE_OUTLINE)
    fill(image, 4, 26, 27, 26, BASE_BODY_LIGHT)
    put(image, 4, 26, BASE_WHITE)
    put(image, 27, 26, BASE_SHADOW)

    # 正面主体：y=27..29。上方亮、下方灰蓝，左高光、右阴影。
    for y, body, left in ((27, BASE_BODY_LIGHT, BASE_WHITE),
                          (28, BASE_BODY, BASE_WHITE),
                          (29, BASE_BODY_MID, BASE_SHADOW)):
        fill(image, 4, y, 27, y, body)
        put(image, 4, y, BASE_OUTLINE)
        put(image, 27, y, BASE_OUTLINE)
        put(image, 5, y, left)
        put(image, 24, y, BASE_BODY_MID)
        put(image, 25, y, BASE_SHADOW)
        put(image, 26, y, BASE_SHADOW_DEEP)

    # 轻微石缝：不在中央符文上，不形成深色大块。
    put(image, 9, 28, BASE_SEAM)
    put(image, 9, 29, BASE_SEAM)
    put(image, 22, 27, BASE_SEAM)
    put(image, 22, 28, BASE_SEAM)
    put(image, 23, 29, BASE_SHADOW)

    # 中央金色小符文：空心菱形 + 中心一点，避免读成正极加号。
    put(image, 15, 27, GOLD_LIGHT)
    put(image, 16, 27, GOLD)
    put(image, 14, 28, GOLD_DARK)
    put(image, 17, 28, GOLD_DARK)
    put(image, 16, 28, GOLD_LIGHT)  # 单点中心，保持不对称的“眼”形符文
    put(image, 15, 29, GOLD)
    put(image, 16, 29, GOLD_DARK)
    put(image, 11, 28, GOLD_DIM)

    # 底脚：y=30..31，比主体宽，顶面亮、底面压暗，表现厚度。
    fill(image, 2, 30, 29, 30, BASE_FOOT_LIGHT)
    put(image, 2, 30, BASE_OUTLINE)
    put(image, 29, 30, BASE_OUTLINE)
    put(image, 3, 30, BASE_FOOT)
    put(image, 28, 30, BASE_FOOT)
    put(image, 4, 30, BASE_WHITE)
    put(image, 27, 30, BASE_SHADOW)
    fill(image, 4, 30, 26, 30, BASE_FOOT_LIGHT)
    fill(image, 3, 31, 28, 31, BASE_FOOT_SHADOW)
    put(image, 3, 31, BASE_OUTLINE_DARK)
    put(image, 28, 31, BASE_OUTLINE_DARK)
    fill(image, 4, 31, 27, 31, BASE_SHADOW_DEEP)
    fill(image, 5, 31, 26, 31, BASE_FOOT_SHADOW)
    return image


def draw_glass() -> Image.Image:
    """浅青钟形玻璃罩；内腔在星核 16×16 矩形内必须完全透明。"""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # 半圆帽 + 两像素厚边。中心 (15.5,16.0)，外半径 15、内半径 13。
    for y in range(1, 16):
        for x in range(0, SIZE):
            dx = (x + 0.5) - CENTER_X
            dy = (y + 0.5) - CENTER_Y
            radius = math.hypot(dx, dy)
            if INNER_RADIUS <= radius <= OUTER_RADIUS:
                if radius >= 14.0:
                    color = GLASS_OUTER
                else:
                    color = GLASS_MID
                # 右侧略深，给玻璃一点体积感；左侧保留浅青亮边。
                if dx > 3.0 and radius >= 13.8:
                    color = GLASS_DEEP if radius < 14.6 else GLASS_MID
                put(image, x, y, color)

    # 短直壁：从半圆脚 y=16 接到 y=23。
    for y in range(16, 24):
        put(image, 1, y, GLASS_OUTER)
        put(image, 2, y, GLASS_MID)
        put(image, 29, y, GLASS_MID)
        put(image, 30, y, GLASS_DEEP)

    # 底座顶沿的玻璃封圈：只画在 y=24，不覆盖 y=23 的星核底边。
    for x in range(2, 30):
        put(image, x, 24, GLASS_SEAL)
    for x in range(4, 28):
        put(image, x, 24, GLASS_SEAL_LIGHT)
    for x in (7, 8, 24, 25):
        put(image, x, 24, GLASS_GLINT_SOFT)

    # 少量白反光：集中在左上外沿，不进入星核矩形。
    for x, y in ((10, 2), (9, 2), (8, 3), (7, 4), (6, 5)):
        put(image, x, y, GLASS_GLINT)
    put(image, 5, 6, GLASS_GLINT_SOFT)
    put(image, 2, 9, GLASS_GLINT_SOFT)
    put(image, 2, 10, GLASS_GLINT_SOFT)

    # 内部极淡反射：x=5..6 与 x=26..27，均在 16px 星核矩形外。
    for y in range(12, 20):
        put(image, 5, y, GLASS_WEAK)
    for y in range(14, 18):
        put(image, 6, y, (255, 255, 255, 28))
    for y in range(16, 23):
        put(image, 26, y, GLASS_WEAK_CYAN)
    for x, y in ((10, 5), (11, 5), (9, 6)):
        put(image, x, y, (255, 255, 255, 34))

    # 极淡的内沿提示，贴着星核左右边缘但不压住核心。
    for y in (11, 12, 19, 20):
        put(image, 7, y, (173, 240, 244, 26))
        put(image, 24, y, (173, 240, 244, 22))

    return image


def compose(base: Image.Image, glass: Image.Image,
            core: Image.Image | None = None) -> Image.Image:
    empty = Image.alpha_composite(base, glass)
    if core is None:
        return empty
    core_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    core_layer.paste(core, (CORE_RECT[0], CORE_RECT[1]), core)
    result = Image.alpha_composite(base, core_layer)
    return Image.alpha_composite(result, glass)


def draw_lock_marker(image: Image.Image) -> None:
    """评审预览用：复刻 Godot 组件在底座正面右侧绘制的 4×3 金色小锁。"""
    # 图像坐标 x=20..23, y=27..29（相对星核仓原点 x=4..7, y=11..13）。
    for x in (21, 22):
        image.putpixel((x, 27), GOLD_LIGHT)
    for x in range(20, 24):
        image.putpixel((x, 28), GOLD)
        image.putpixel((x, 29), GOLD)
    image.putpixel((20, 28), GOLD_DARK)
    image.putpixel((23, 28), GOLD_DARK)
    image.putpixel((23, 29), GOLD_DARK)
    image.putpixel((21, 28), GOLD_LIGHT)
    image.putpixel((21, 29), (76, 93, 105, 255))
    image.putpixel((22, 29), (76, 93, 105, 255))


def draw_checker(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], cell: int) -> None:
    x0, y0, x1, y1 = box
    colors = ((54, 60, 68), (41, 47, 55))
    for yy in range(y0, y1, cell):
        for xx in range(x0, x1, cell):
            index = ((xx - x0) // cell + (yy - y0) // cell) % 2
            draw.rectangle(
                (xx, yy, min(xx + cell - 1, x1 - 1), min(yy + cell - 1, y1 - 1)),
                fill=colors[index],
            )


def scaled(image: Image.Image, factor: int) -> Image.Image:
    return image.resize((image.width * factor, image.height * factor), Image.Resampling.NEAREST)


def make_review(base: Image.Image, glass: Image.Image, empty: Image.Image,
                core: Image.Image, occupied: Image.Image) -> Image.Image:
    """内部评审大图：8x 分层 + 1x/4x 组合 + 主角真实比例参照。"""
    scale8 = 8
    scale4 = 4
    cell = SIZE * scale8
    card_w, card_h = 296, 360
    gap = 16
    margin = 24
    width = margin * 2 + card_w * 4 + gap * 3
    height = 900
    canvas = Image.new("RGB", (width, height), (22, 28, 35))
    draw = ImageDraw.Draw(canvas)

    f_title = font(FONT_CN_BOLD, 30)
    f_sub = font(FONT_CN, 15)
    f_card = font(FONT_CN_BOLD, 17)
    f_small = font(FONT_CN, 12)
    f_small_bold = font(FONT_CN_BOLD, 12)
    f_mono = font(FONT_MONO, 10)
    f_note = font(FONT_CN, 12)

    draw.text((margin, 18), "星核仓首版 · 32×32 侧视像素分层", font=f_title, fill=(240, 243, 236))
    draw.text(
        (margin, 58),
        "白色石质底座（后层） / 既有 16×16 紫色星核（中） / 浅青半圆钟形玻璃（前层） · 程序化像素，无外部生成",
        font=f_sub,
        fill=(157, 175, 185),
    )
    draw.text((width - margin - 190, 24), "FIRST-PASS LOOK DEV", font=f_mono, fill=(127, 151, 163))

    cards = [
        ("BASE / 后层", "star_core_bay_base.png", base, "白底座 + 灰蓝阴影 + 少量金符文"),
        ("EXISTING CORE / 中", "star_core_locked.png", core, "工程既有 16×16 紫核，不改原素材"),
        ("GLASS / 前层", "star_core_bay_glass.png", glass, "浅青边缘、少量白反光、内部清透"),
        ("OCCUPIED / 合成参照", "base + core + glass", occupied, "锁定小标识由 Godot 代码绘制，不烘焙"),
    ]

    card_y = 96
    for index, (title, filename, image, note) in enumerate(cards):
        x = margin + index * (card_w + gap)
        draw.rounded_rectangle((x, card_y, x + card_w, card_y + card_h), radius=5,
                               fill=(30, 37, 45), outline=(51, 64, 76), width=1)
        draw.rectangle((x + 1, card_y + 1, x + card_w - 1, card_y + 4), fill=(104, 181, 190))
        draw.text((x + 16, card_y + 14), title, font=f_card, fill=(230, 239, 235))
        draw.text((x + 16, card_y + 38), filename, font=f_mono, fill=(145, 172, 180))

        image_box = (x + 20, card_y + 62, x + 20 + cell, card_y + 62 + cell)
        draw_checker(draw, image_box, 16)
        if image is core:
            # 16×16 核心在 32×32 仓体里按 8x 居中；虚线框表示仓体范围。
            core_big = scaled(core, scale8)
            draw.rectangle(image_box, outline=(65, 83, 95), width=1)
            cx = x + 20 + (cell - core_big.width) // 2
            cy = card_y + 62 + (cell - core_big.height) // 2
            canvas.paste(core_big, (cx, cy), core_big)
            dash = (82, 104, 116)
            for offset in range(0, cell, 12):
                draw.line((image_box[0] + offset, image_box[1] + 1,
                           min(image_box[0] + offset + 6, image_box[2] - 1), image_box[1] + 1),
                          fill=dash, width=1)
                draw.line((image_box[0] + offset, image_box[3] - 1,
                           min(image_box[0] + offset + 6, image_box[2] - 1), image_box[3] - 1),
                          fill=dash, width=1)
        else:
            big = scaled(image, scale8)
            canvas.paste(big, (image_box[0], image_box[1]), big)
            draw.rectangle(image_box, outline=(65, 83, 95), width=1)
        draw.text((x + 16, card_y + 326), note, font=f_small, fill=(139, 159, 170))
        draw.text((x + 16, card_y + 344), "32×32 · NEAREST", font=f_mono, fill=(112, 135, 147))

    # ---- 第二行：4x、1x 与主角比例 ----
    row_y = 486
    draw.text((margin, row_y), "真实尺寸 / 4× 近看 / 主角比例", font=f_card, fill=(230, 239, 235))
    draw.text((margin + 286, row_y + 4),
              "1× 是游戏内真实像素；4× 只用于预览。主角 idle 截帧 32×37 可见像素，仅作比例参照。",
              font=f_small, fill=(139, 159, 170))

    ground_y = 690
    # 4x 空仓 / 满仓（左侧）
    empty4 = scaled(empty, scale4)
    occupied4 = scaled(occupied, scale4)
    canvas.paste(empty4, (24, ground_y - 128), empty4)
    canvas.paste(occupied4, (176, ground_y - 128), occupied4)
    draw.rectangle((23, ground_y - 129, 23 + 128, ground_y + 1), outline=(65, 83, 95), width=1)
    draw.rectangle((175, ground_y - 129, 175 + 128, ground_y + 1), outline=(65, 83, 95), width=1)
    draw.text((24, ground_y + 8), "EMPTY 4×", font=f_small, fill=(169, 190, 198))
    draw.text((176, ground_y + 8), "OCCUPIED 4×", font=f_small, fill=(169, 190, 198))

    # 1x 空仓 / 满仓 / 核心 / 主角（右侧，共用地面线）
    draw.line((332, ground_y, 640, ground_y), fill=(78, 101, 114), width=1)
    empty1 = scaled(empty, 1)
    occupied1 = scaled(occupied, 1)
    canvas.paste(empty1, (352, ground_y - SIZE), empty1)
    canvas.paste(occupied1, (432, ground_y - SIZE), occupied1)
    canvas.paste(core, (520, ground_y - 16), core)
    player = Image.open(
        PROJECT_ROOT / "基础场景原型" / "assets" / "characters" / "male_hero-idle.png"
    ).convert("RGBA").crop((41, 43, 73, 80))
    canvas.paste(player, (590, ground_y - player.height), player)

    draw.text((332, ground_y + 8), "EMPTY 1×", font=f_small, fill=(169, 190, 198))
    draw.text((410, ground_y + 8), "OCCUPIED 1×", font=f_small, fill=(169, 190, 198))
    draw.text((500, ground_y + 8), "CORE 16px", font=f_small, fill=(169, 190, 198))
    draw.text((574, ground_y + 8), "PLAYER 1×", font=f_small, fill=(169, 190, 198))
    draw.text((574, ground_y + 26), "32×37 px", font=f_mono, fill=(118, 142, 154))

    # 右侧说明
    draw.text((690, row_y), "几何与分层检查", font=f_card, fill=(230, 239, 235))
    notes = [
        "· 三张导出 PNG 均为 32×32，同原点。",
        "· 核心 16×16 放在 (0,0)，图像范围 x=8..23、y=8..23。",
        "· 底座从 y=24 开始，核心底边 y=23，不压底座。",
        "· 玻璃在核心整块 16×16 内 alpha=0，核心完整透出。",
        "· 半圆帽外半径 15；短直壁到 y=24，16px 核心完整在罩内。",
        "· 严格正半圆在 32px 内放不下 16px 核心；",
        "  若必须严格正半圆，需把仓体加宽到约 44×32（留边 46×32），",
        "  不是只加高；32×40 只能做更高的半椭圆/钟形。",
        "· 锁定小标识由 Godot 代码绘制，不烘焙进 PNG；",
        "  空仓图只有底座 + 玻璃，不含核心。",
        "· 本目录含生成脚本、README、manifest、对比预览；",
        "  工程只放必要分层 PNG。",
    ]
    y = row_y + 34
    for line in notes:
        draw.text((690, y), line, font=f_note, fill=(142, 163, 173))
        y += 21

    # 色板小条
    swatches = [
        ("WHITE BASE", (238, 242, 237, 255)),
        ("GREY-BLUE", (144, 164, 174, 255)),
        ("PALE CYAN", (172, 234, 239, 255)),
        ("GOLD RUNE", (218, 176, 86, 255)),
        ("PURPLE CORE", (233, 155, 247, 255)),
    ]
    x = 690
    for label, color in swatches:
        draw.rectangle((x, 792, x + 12, 804), fill=color[:3], outline=(90, 112, 124), width=1)
        draw.text((x + 17, 791), label, font=f_mono, fill=(127, 151, 163))
        x += 112

    draw.line((margin, 818, width - margin, 818), fill=(49, 61, 73), width=1)
    footer = (
        "本图是本地 NEAREST 像素合成预览，不是 Godot 引擎截图，也不是最终美术定稿。",
        "底座/玻璃为项目自制程序化像素；合成参照中的紫色星核为既有 Frakassets CC BY 4.0 素材，原文件未修改。",
        "锁定小标识由 star_core_bay_visual.gd 在底座上绘制；PNG 中不烘焙标识，导出空仓图也不含核心。",
    )
    y = 830
    for line in footer:
        draw.text((margin, y), line, font=f_note, fill=(139, 159, 170))
        y += 21
    return canvas


def main() -> None:
    if not STAR_CORE_LOCKED.exists():
        raise SystemExit(f"找不到既有紫色星核: {STAR_CORE_LOCKED}")

    source_hash_before = sha256_file(STAR_CORE_LOCKED)
    core = Image.open(STAR_CORE_LOCKED).convert("RGBA")
    if core.size != (16, 16):
        raise SystemExit(f"星核尺寸异常: {core.size}，预期 (16, 16)")

    base = draw_base()
    glass = draw_glass()
    empty = compose(base, glass)
    occupied = compose(base, glass, core)
    draw_lock_marker(occupied)

    PROJECT_ASSET_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "base": ("star_core_bay_base.png", base),
        "glass": ("star_core_bay_glass.png", glass),
        "empty": ("star_core_bay_empty.png", empty),
    }
    for key, (filename, image) in outputs.items():
        image.save(PROJECT_ASSET_DIR / filename, "PNG", optimize=True)
        shutil.copy2(PROJECT_ASSET_DIR / filename, HERE / filename)

    # 从磁盘重新读取，验证保存后的真实 RGBA。
    saved = {
        key: Image.open(PROJECT_ASSET_DIR / filename).convert("RGBA")
        for key, (filename, _) in outputs.items()
    }

    source_hash_after = sha256_file(STAR_CORE_LOCKED)
    source_unchanged = source_hash_before == source_hash_after

    base_alpha = saved["base"].getchannel("A")
    glass_alpha = saved["glass"].getchannel("A")
    empty_alpha = saved["empty"].getchannel("A")

    base_bbox = base_alpha.getbbox()
    glass_bbox = glass_alpha.getbbox()
    base_pixels_above_pedestal = 0
    core_glass_alpha_max = 0
    for y in range(CORE_RECT[1], CORE_RECT[3]):
        for x in range(CORE_RECT[0], CORE_RECT[2]):
            if base_alpha.getpixel((x, y)) > 0:
                base_pixels_above_pedestal += 1
            core_glass_alpha_max = max(core_glass_alpha_max, glass_alpha.getpixel((x, y)))

    # 星核四周的玻璃是否构成完整外轮廓：逐行检查核心矩形四角在外轮廓内。
    inside_dome = True
    for y in range(CORE_RECT[1], CORE_RECT[3]):
        py = y + 0.5
        if py < 16.0:
            half = math.sqrt(max(0.0, OUTER_RADIUS ** 2 - (py - CENTER_Y) ** 2))
            left, right = CENTER_X - half, CENTER_X + half
        else:
            left, right = 1.0, 31.0
        if not (left <= CORE_RECT[0] and CORE_RECT[2] - 1 <= right):
            inside_dome = False
            break

    # 白底座明度与金符文检查（只看不透明像素）。
    opaque_lums = []
    gold_pixels = 0
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = saved["base"].getpixel((x, y))
            if a == 0:
                continue
            opaque_lums.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
            if r > 120 and r > b + 35 and g > b + 15 and r > g:
                gold_pixels += 1
    mean_lum = sum(opaque_lums) / len(opaque_lums)

    bright_white_glints = 0
    cyan_pixels = 0
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = saved["glass"].getpixel((x, y))
            if a == 0:
                continue
            if r >= 245 and g >= 245 and b >= 245 and a >= 120:
                bright_white_glints += 1
            if g > r + 20 and b > r + 20:
                cyan_pixels += 1

    empty_expected = Image.alpha_composite(saved["base"], saved["glass"])
    empty_matches = empty_expected.tobytes() == saved["empty"].tobytes()
    all_sizes = all(image.size == (SIZE, SIZE) for image in saved.values())
    all_modes = all(image.mode == "RGBA" for image in saved.values())
    alpha_preserved = all(image.getchannel("A").getextrema()[1] > 0 for image in saved.values())
    corners_transparent = all(
        saved[key].getpixel((0, 0))[3] == 0
        and saved[key].getpixel((SIZE - 1, 0))[3] == 0
        and saved[key].getpixel((0, SIZE - 1))[3] == 0
        and saved[key].getpixel((SIZE - 1, SIZE - 1))[3] == 0
        for key in saved
    )

    checks = {
        "all_sizes_32x32": all_sizes,
        "all_modes_rgba": all_modes,
        "alpha_preserved": alpha_preserved,
        "corners_transparent": corners_transparent,
        "base_bbox": list(base_bbox) if base_bbox else None,
        "glass_bbox": list(glass_bbox) if glass_bbox else None,
        "base_alpha_pixels_above_y24": base_pixels_above_pedestal,
        "core_rect_glass_alpha_max": core_glass_alpha_max,
        "core_rect_glass_transparent": core_glass_alpha_max == 0,
        "core_inside_dome_outer": inside_dome,
        "core_bottom_above_base_top": CORE_RECT[3] - 1 < PEDESTAL_TOP,
        "empty_is_base_plus_glass": empty_matches,
        "base_mean_opaque_luminance": round(mean_lum, 2),
        "base_is_bright": mean_lum >= 150.0,
        "gold_rune_pixel_count": gold_pixels,
        "glass_bright_white_glint_pixels": bright_white_glints,
        "glass_cyan_edge_pixels": cyan_pixels,
        "source_core_unchanged": source_unchanged,
        "source_core_size": list(core.size),
        "core_rect": list(CORE_RECT),
        "pedestal_top_y": PEDESTAL_TOP,
    }

    failed = [
        key for key, value in checks.items()
        if isinstance(value, bool) and not value
    ]
    if failed:
        raise SystemExit("自检失败: " + ", ".join(failed))

    review = make_review(saved["base"], saved["glass"], saved["empty"], core, occupied)
    review_path = HERE / "star_core_bay_review.png"
    review.save(review_path, "PNG", optimize=True)

    manifest = {
        "name": "星核旅人 · 星核仓首版（32×32 侧视像素分层）",
        "version": 1,
        "status": "prototype first pass, pending user visual feedback; not final art",
        "generated_by": "generate_star_core_bay.py (Pillow, deterministic programmatic pixel art)",
        "design": {
            "view": "side view pixel art",
            "canvas": [SIZE, SIZE],
            "origin": "center of the 32×32 bay; all layers share the same origin",
            "base": "white stone pedestal with grey-blue shading and thickness, starting at image y=24",
            "glass": "pale-cyan bell dome: semicircular cap (outer radius 15) plus short vertical walls to y=24",
            "glass_interior": "fully transparent over the core's 16×16 rect; only rim, seal and outside-core reflections are opaque",
            "core": "existing 16×16 purple star core at (0,0), image rect x=8..23, y=8..23",
            "core_bottom_y": 23,
            "pedestal_top_y": 24,
            "core_base_overlap": False,
            "gold_runes": "small hollow diamond with a center dot plus one dim stud on the pedestal front",
            "lock_marker": "4×3 code-drawn gold padlock on the pedestal; not baked into any PNG",
            "dome_geometry_note": "A strict semicircle cannot enclose a 16×16 core above an 8px pedestal in 32×32: at the core top (16px above the base) a 32-wide strict semicircle would be only the apex, and its radius is just 16. The 32×32 bay therefore uses a semicircular cap plus short vertical walls; the core is not scaled and the pedestal is not redesigned. If a strict semicircle is mandatory, widen the canvas to about 44×32 (46×32 with margin), not merely 32×40: a taller 32×40 can host a half-ellipse/bell, not a strict semicircle.",
        },
        "layer_order": ["StarCoreBayVisual/Base (rear)", "StarCoreBayVisual/Core (existing 16×16 purple)", "StarCoreBayVisual/Glass (front)"],
        "assets": {
            key: {
                "file": filename,
                "project_path": f"基础场景原型/assets/star_core_bay/{filename}",
                "backup_path": f"自制素材/星核仓/{filename}",
                "size": list(saved[key].size),
                "mode": saved[key].mode,
                "opaque_pixels": sum(1 for value in saved[key].getchannel("A").tobytes() if value > 0),
                "sha256": sha256_file(PROJECT_ASSET_DIR / filename),
                "rgba_sha256": sha256_rgba(saved[key]),
            }
            for key, (filename, _) in outputs.items()
        },
        "checks": checks,
        "source": {
            "core_file": "基础场景原型/assets/star_core/star_core_locked.png",
            "core_sha256_before": source_hash_before,
            "core_sha256_after": source_hash_after,
            "core_unchanged": source_unchanged,
            "core_attribution": 'Free Shiny Gem "Round" by Frakassets, CC BY 4.0, https://frakassets.itch.io/free-shiny-gem-round',
            "note": "The existing purple core is only composited in the review image, the Godot scene, and the engine preview screenshot; no existing asset was modified.",
        },
        "review_artifacts": {
            "review_image": {
                "file": "star_core_bay_review.png",
                "size": list(review.size),
                "mode": "RGB",
                "sha256": sha256_file(review_path),
                "note": "Local nearest-neighbour composite review, not a Godot engine capture. Checkerboard, labels and the code-lock replica are not part of any exported PNG. The 1x player idle crop is the project's existing character art, used only for scale; its license is still unknown, so this sheet is for internal review only.",
            }
        },
        "integration": {
            "godot_assets": "res://assets/star_core_bay/",
            "godot_scene": "res://scenes/star_core_bay_visual.tscn",
            "godot_script": "res://scripts/star_core_bay_visual.gd",
            "preview_scene": "res://tools/preview_star_core_bay.tscn",
            "preview_capture": "res://screenshots/star_core_bay_preview.png",
            "core_state": "LOCKED (purple); the original StarCoreVisual bottom-right badge is disabled by the bay scene",
            "occupied_export": "occupied: bool (default true) hides/shows the existing core and the code lock marker; pure display, no bay logic",
            "not_included": "no opening animation, no storage/retrieval interaction, no collision, no suction, no default main scene wiring, no formal level layout",
        },
        "notes": [
            "All three exported PNGs are 32×32, same origin. The empty composite is base+glass only; no core is baked in.",
            "The glass layer is genuinely transparent over the full 16×16 core rect, verified by alpha sampling.",
            "The review image's occupied composite is a reference only; the game scene layers base, the existing core, and glass separately.",
            "This is a first-pass look-dev asset pending user visual feedback, not final art.",
        ],
    }
    (HERE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print("生成完成:", HERE)
    print("工程资产:", PROJECT_ASSET_DIR)
    for key, meta in manifest["assets"].items():
        print(f"  {key:5s} {meta['file']}  sha256={meta['sha256']}  opaque={meta['opaque_pixels']}")
    print("checks:", json.dumps(checks, ensure_ascii=False))
    print("review:", review_path)


if __name__ == "__main__":
    main()
