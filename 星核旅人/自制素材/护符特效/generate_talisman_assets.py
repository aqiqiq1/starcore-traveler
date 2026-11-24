#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
星核旅人 · 胸前极性护符素材生成器
--------------------------------
只使用 Pillow + 手写像素矩阵/距离场，从零绘制 5x5 护符、11x11 光晕和
24x24 扩散环，并合成角色叠放预览。不会修改 individual_sheets/ 中的原角色。

运行（项目自带 conda 环境）:
    D:\\minic\\envs\\2024212971\\python.exe generate_talisman_assets.py

调色:
    修改 PALETTES 中 gold / cyan 的颜色即可整体重制；两种极性共用完全相同的
    alpha 形状。预览放大使用 NEAREST，不经过模糊/缩放插值。
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parents[1]
CHARACTER_SHEET = PROJECT_ROOT / "individual_sheets" / "male_hero-idle.png"
PREVIEW_FRAME = 0
FRAME_SIZE = 128
# idle #0: 可见像素 bbox (41, 43, 73, 80)，胸甲中心取 (64, 63)。
SPRITE_ANCHOR = (64, 64)
CHEST_ANCHOR = (64, 63)
TALISMAN_SIZE = 5
TALISMAN_TOP_LEFT = (CHEST_ANCHOR[0] - 2, CHEST_ANCHOR[1] - 2)  # (62, 61)

PALETTES = {
    "gold": {
        "label": "正极 · 暖金",
        "outline": (72, 41, 17, 255),
        "dark": (142, 75, 13, 255),
        "base": (216, 139, 30, 255),
        "light": (251, 190, 71, 255),
        "core": (255, 247, 196, 255),
        "glow_outer": (236, 155, 38),
        "glow_inner": (255, 244, 186),
        "ring": (255, 199, 73),
        "ring_tip": (255, 248, 201),
    },
    "cyan": {
        "label": "负极 · 冷青",
        "outline": (9, 43, 53, 255),
        "dark": (12, 88, 104, 255),
        "base": (33, 157, 171, 255),
        "light": (99, 224, 227, 255),
        "core": (226, 255, 255, 255),
        "glow_outer": (39, 196, 210),
        "glow_inner": (219, 255, 255),
        "ring": (86, 224, 231),
        "ring_tip": (226, 255, 255),
    },
}

# 5x5 圆形徽章。两种极性共用同一 alpha 形状；所有可见像素均不透明。
TALISMAN_MASK = (
    "01110",
    "11111",
    "11111",
    "11111",
    "01110",
)
# 3x3 内芯：上左 L 形 3 像素高光，右下压暗，形成薄宝石感。
TALISMAN_INNER = (
    ("light", "core", "base"),
    ("core", "core", "base"),
    ("dark", "base", "base"),
)

GLOW_SIZE = 11
GLOW_CENTER = (5, 5)
# 4 帧呼吸：半径由小到大再回收；alpha 同步变化。不使用模糊。
GLOW_FRAMES = (
    (3.40, 0.72),
    (4.05, 0.86),
    (4.80, 1.00),
    (4.35, 0.90),
)
GLOW_ALPHA_STEPS = (232, 168, 112, 64)

RING_SIZE = 24
RING_CENTER = (12, 12)
# (半径, 半线宽, alpha)。最后一帧仍保留 140 alpha，避免放大后只剩不可见点。
RING_FRAMES = (
    (3.4, 0.95, 255),
    (6.0, 1.15, 230),
    (8.3, 0.58, 185),
    (10.0, 0.58, 142),
)

FONT_CN = "C:/Windows/Fonts/msyh.ttc"
FONT_CN_BOLD = "C:/Windows/Fonts/msyhbd.ttc"
FONT_MONO = "C:/Windows/Fonts/consola.ttf"
FONT_MONO_BOLD = "C:/Windows/Fonts/consolab.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def save_png(image: Image.Image, name: str) -> Path:
    path = HERE / name
    image.save(path, "PNG", optimize=True)
    return path


def make_talisman(palette: dict) -> Image.Image:
    """5x5 原生像素护符，透明底，细暗轮廓。"""
    image = Image.new("RGBA", (TALISMAN_SIZE, TALISMAN_SIZE), (0, 0, 0, 0))
    for y, row in enumerate(TALISMAN_MASK):
        for x, on in enumerate(row):
            if on != "1":
                continue
            # 外圈一圈暗边；内部用 3x3 明暗小矩阵。
            if y in (0, 4) or x in (0, 4):
                color = palette["outline"]
            else:
                role = TALISMAN_INNER[y - 1][x - 1]
                color = palette[role]
            image.putpixel((x, y), color)
    return image


def glow_pixel(distance: float, radius: float, palette: dict, strength: float) -> tuple[int, int, int, int] | None:
    """离散 alpha 层；只做像素级比较，不做模糊/抗锯齿。"""
    if distance > radius:
        return None
    ratio = distance / radius
    if ratio <= 0.28:
        step = 0
    elif ratio <= 0.58:
        step = 1
    elif ratio <= 0.84:
        step = 2
    else:
        step = 3
    alpha = max(0, min(255, round(GLOW_ALPHA_STEPS[step] * strength)))
    if alpha < 28:
        return None
    t = min(1.0, ratio)
    outer = palette["glow_outer"]
    inner = palette["glow_inner"]
    color = tuple(round(outer[i] * t + inner[i] * (1.0 - t)) for i in range(3))
    return color + (alpha,)


def make_glow_frame(palette: dict, frame_index: int) -> Image.Image:
    radius, strength = GLOW_FRAMES[frame_index]
    image = Image.new("RGBA", (GLOW_SIZE, GLOW_SIZE), (0, 0, 0, 0))
    cx, cy = GLOW_CENTER
    for y in range(GLOW_SIZE):
        for x in range(GLOW_SIZE):
            d = math.hypot(x - cx, y - cy)
            pixel = glow_pixel(d, radius, palette, strength)
            if pixel:
                image.putpixel((x, y), pixel)
    return image


def pasted_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.alpha_composite(frame, (i * frame.width, 0))
    return sheet


def ring_frame(palette: dict, frame_index: int) -> Image.Image:
    radius, half_width, alpha = RING_FRAMES[frame_index]
    image = Image.new("RGBA", (RING_SIZE, RING_SIZE), (0, 0, 0, 0))
    cx, cy = RING_CENTER
    base = palette["ring"]
    tip = palette["ring_tip"]
    for y in range(RING_SIZE):
        for x in range(RING_SIZE):
            d = math.hypot(x - cx, y - cy)
            if abs(d - radius) > half_width:
                continue
            # 四个正方向各留 1 个更亮像素，保持环完整且增加像素手绘感。
            is_tip = (abs(x - cx) < 0.25 or abs(y - cy) < 0.25) and abs(d - radius) < 0.65
            color = tip if is_tip else base
            image.putpixel((x, y), color + (alpha,))
    return image


def draw_checkerboard(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], cell: int = 8) -> None:
    x0, y0, x1, y1 = box
    colors = ((28, 34, 42), (34, 41, 50))
    for yy in range(y0, y1, cell):
        for xx in range(x0, x1, cell):
            idx = ((xx - x0) // cell + (yy - y0) // cell) % 2
            draw.rectangle((xx, yy, min(xx + cell - 1, x1 - 1), min(yy + cell - 1, y1 - 1)), fill=colors[idx])


def paste_cell(base: Image.Image, sprite: Image.Image, box: tuple[int, int, int, int], scale: int) -> None:
    """把透明精灵以 NEAREST 整数放大放入预览格（棋盘仅存在于预览中）。"""
    draw = ImageDraw.Draw(base)
    draw_checkerboard(draw, box, 8)
    draw.rectangle(box, outline=(62, 75, 88), width=2)
    scaled = sprite.resize((sprite.width * scale, sprite.height * scale), Image.Resampling.NEAREST)
    px = box[0] + (box[2] - box[0] - scaled.width) // 2
    py = box[1] + (box[3] - box[1] - scaled.height) // 2
    base.alpha_composite(scaled, (px, py))


def compose_chest_preview(character_frame: Image.Image, talisman: Image.Image, glow_frame: Image.Image) -> Image.Image:
    """返回 64x64 的原生合成（之后由调用方整数放大）。"""
    native = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    # 裁切范围：x=32..96, y=30..94，保留整个人物并留下边缘呼吸。
    body = character_frame.crop((32, 30, 96, 94))
    glow_pos = (CHEST_ANCHOR[0] - GLOW_SIZE // 2 - 32, CHEST_ANCHOR[1] - GLOW_SIZE // 2 - 30)
    # 光晕在角色后方，避免覆盖脸、围巾和身体；护符本体在角色前方。
    native.alpha_composite(glow_frame, glow_pos)
    native.alpha_composite(body, (0, 0))
    native.alpha_composite(talisman, (TALISMAN_TOP_LEFT[0] - 32, TALISMAN_TOP_LEFT[1] - 30))
    return native


def make_character_canvas(native: Image.Image, scale: int, title: str, subtitle: str, tag: str, accent: tuple[int, int, int]) -> Image.Image:
    margin = 34
    header = 74
    footer = 74
    panel_w = native.width * scale
    panel_h = native.height * scale
    canvas = Image.new("RGBA", (panel_w + margin * 2, header + panel_h + footer), (22, 28, 36, 255))
    draw = ImageDraw.Draw(canvas)
    # 极轻的 8px 网格，只服务预览，不属于任何 PNG 素材。
    for gx in range(margin, margin + panel_w, 8 * scale):
        draw.line((gx, header, gx, header + panel_h), fill=(27, 34, 43, 255), width=1)
    for gy in range(header, header + panel_h, 8 * scale):
        draw.line((margin, gy, margin + panel_w, gy), fill=(27, 34, 43, 255), width=1)
    draw.rectangle((margin - 10, header - 10, margin + panel_w + 10, header + panel_h + 10), outline=(45, 56, 68, 255), width=2)

    scaled = native.resize((panel_w, panel_h), Image.Resampling.NEAREST)
    canvas.alpha_composite(scaled, (margin, header))

    f_title = font(FONT_CN_BOLD, 30)
    f_sub = font(FONT_CN, 16)
    f_tag = font(FONT_CN_BOLD, 19)
    f_foot = font(FONT_MONO, 11)
    draw.text((margin, 18), title, font=f_title, fill=(238, 241, 235, 255))
    draw.text((margin, 52), subtitle, font=f_sub, fill=(150, 168, 177, 255))
    # 右上角状态标签
    tag_w = draw.textbbox((0, 0), tag, font=f_tag)[2] + 22
    draw.rounded_rectangle((canvas.width - margin - tag_w, 22, canvas.width - margin, 54), radius=4, fill=accent + (38,), outline=accent + (230,), width=2)
    draw.text((canvas.width - margin - tag_w + 11, 28), tag, font=f_tag, fill=accent + (255,))
    # 页脚只写定位事实，不宣称引擎实测。
    draw.text((margin, header + panel_h + 22), "本地像素合成预览 · 非 Godot 实测 · 原角色未修改", font=f_sub, fill=(188, 200, 204, 255))
    draw.text((margin, header + panel_h + 46), "idle #0  |  anchor (64,64)  |  chest px (64,63)  |  centered=false", font=f_foot, fill=(117, 139, 151, 255))
    return canvas


def make_compare_preview(character_frame: Image.Image, talismans: dict, glows: dict) -> Image.Image:
    gold_native = compose_chest_preview(character_frame, talismans["gold"], glows["gold"][2])
    cyan_native = compose_chest_preview(character_frame, talismans["cyan"], glows["cyan"][2])
    scale = 8
    gold_panel = make_character_canvas(
        gold_native, scale,
        "星核旅人 · 胸前极性护符",
        "正极 / 负极 同一 idle 帧叠加对照  ·  本地像素合成，不是游戏截图",
        "正极 · 暖金", (247, 190, 72),
    )
    cyan_panel = make_character_canvas(
        cyan_native, scale,
        "星核旅人 · 胸前极性护符",
        "极性与角色姿势无关；此预览仅固定 idle #0，不代表其它动作已适配",
        "负极 · 冷青", (92, 225, 232),
    )
    gap = 22
    combined = Image.new("RGBA", (gold_panel.width + cyan_panel.width + gap, gold_panel.height), (18, 23, 30, 255))
    combined.alpha_composite(gold_panel, (0, 0))
    combined.alpha_composite(cyan_panel, (gold_panel.width + gap, 0))
    return combined, gold_panel, cyan_panel


def make_contact_sheet(talismans: dict, glows: dict, rings: dict) -> Image.Image:
    W, H = 1640, 1410
    image = Image.new("RGBA", (W, H), (19, 25, 32, 255))
    draw = ImageDraw.Draw(image)
    f_title = font(FONT_CN_BOLD, 34)
    f_h2 = font(FONT_CN_BOLD, 21)
    f_small = font(FONT_CN, 15)
    f_label = font(FONT_CN_BOLD, 14)
    f_mono_small = font(FONT_MONO, 12)
    f_frame = font(FONT_MONO_BOLD, 13)

    draw.text((50, 30), "护符特效 · 纯特效放大联系表", font=f_title, fill=(241, 243, 236, 255))
    draw.text((50, 74), "所有特效均为本次程序化像素绘制 / 透明 PNG / NEAREST 整数放大；棋盘背景仅用于透明预览，不属于素材文件。", font=f_small, fill=(151, 172, 181, 255))
    draw.text((50, 98), "GOLD = 正极暖金     CYAN = 负极冷青", font=f_small, fill=(190, 202, 203, 255))

    # ---- 护符本体 ----
    y = 145
    draw.text((50, y), "01  护符本体  Talisman", font=f_h2, fill=(232, 237, 231, 255))
    draw.text((420, y + 4), "5 × 5 px  ·  透明底  ·  细暗边  ·  3 px 中心高光  ·  两色共用同一 alpha 形状", font=f_small, fill=(150, 171, 178, 255))
    y += 42
    for idx, key in enumerate(("gold", "cyan")):
        bx = 50 + idx * 310
        box = (bx, y, bx + 285, y + 245)
        paste_cell(image, talismans[key], box, 17)
        draw.text((bx + 10, y + 8), f"{key.upper()} · {PALETTES[key]['label']}", font=f_label, fill=PALETTES[key]["ring"] + (255,))
        draw.text((bx + 10, y + 220), f"talisman_{key}.png · 5x5", font=f_mono_small, fill=(158, 174, 181, 255))

    note_box = (690, 187, 1590, 432)
    draw.rounded_rectangle(note_box, radius=6, fill=(25, 32, 41, 255), outline=(49, 62, 75, 255), width=2)
    note_lines = (
        ("形状共用", "两色只在 PALETTES 中替换色板；护符 / 光晕 / 扩散环的 alpha 逐像素一致。"),
        ("边缘", "1 px 深色轮廓，中心 3 px 高光；没有模糊、外发光滤镜或 shader。"),
        ("导入", "Godot 4 Sprite2D：centered = false，texture_filter = Nearest，Mipmaps = Off。"),
    )
    for i, (head, body) in enumerate(note_lines):
        yy = note_box[1] + 22 + i * 66
        draw.text((note_box[0] + 24, yy), head, font=font(FONT_CN_BOLD, 16), fill=(223, 229, 222, 255))
        draw.text((note_box[0] + 100, yy), body, font=f_small, fill=(136, 157, 168, 255))

    # ---- 光晕 ----
    y = 470
    draw.text((50, y), "02  脉动光晕  Glow", font=f_h2, fill=(232, 237, 231, 255))
    draw.text((390, y + 4), "11 × 11 px / 4 帧  ·  横向 sprite sheet  ·  8 FPS 循环  ·  无 blur / 无 shader", font=f_small, fill=(150, 171, 178, 255))
    y += 42
    for row, key in enumerate(("gold", "cyan")):
        for i in range(4):
            bx = 50 + i * 250
            by = y + row * 205
            box = (bx, by, bx + 220, by + 160)
            paste_cell(image, glows[key][i], box, 9)
            draw.text((bx + 9, by + 7), f"{key.upper()}  FRAME {i}", font=f_frame, fill=PALETTES[key]["ring"] + (255,))
            draw.text((bx + 9, by + 136), f"glow_{key}_4f.png  ·  F{i}", font=f_mono_small, fill=(158, 174, 181, 255))

    # ---- 扩散环 ----
    y = 920
    draw.text((50, y), "03  切换扩散环  Polarity Switch Ring", font=f_h2, fill=(232, 237, 231, 255))
    draw.text((535, y + 4), "24 × 24 px / 4 帧  ·  20 FPS = 0.20 s  ·  单次播放  ·  最后一帧仍清晰可见", font=f_small, fill=(150, 171, 178, 255))
    y += 42
    for row, key in enumerate(("gold", "cyan")):
        for i in range(4):
            bx = 50 + i * 390
            by = y + row * 222
            box = (bx, by, bx + 370, by + 198)
            # 24 px 环以 6x 放入；上方留标签带，下方留文件名带。
            draw_checkerboard(draw, box, 8)
            draw.rectangle(box, outline=(62, 75, 88), width=2)
            scaled = rings[key][i].resize((RING_SIZE * 6, RING_SIZE * 6), Image.Resampling.NEAREST)
            image.alpha_composite(scaled, (box[0] + (box[2] - box[0] - scaled.width) // 2, by + 24))
            draw.text((bx + 9, by + 6), f"{key.upper()}  FRAME {i}   t={i * 50} ms", font=f_frame, fill=PALETTES[key]["ring"] + (255,))
            draw.text((bx + 9, by + 176), f"switch_ring_{key}_4f.png  ·  F{i}", font=f_mono_small, fill=(158, 174, 181, 255))
    return image


def make_gif(character_frame: Image.Image, talismans: dict, glows: dict, path: Path) -> None:
    """可选切换小 GIF：只换护符/光晕颜色，姿势固定 idle #0。"""
    scale = 5
    margin = 20
    header = 54
    footer = 30
    panel_w = 64 * scale
    panel_h = 64 * scale
    frames = []
    for key in ("gold", "cyan", "gold", "cyan"):
        native = compose_chest_preview(character_frame, talismans[key], glows[key][2])
        canvas = Image.new("RGB", (panel_w + margin * 2, header + panel_h + footer), (22, 28, 36))
        draw = ImageDraw.Draw(canvas)
        for gx in range(margin, margin + panel_w, 8 * scale):
            draw.line((gx, header, gx, header + panel_h), fill=(27, 34, 43), width=1)
        for gy in range(header, header + panel_h, 8 * scale):
            draw.line((margin, gy, margin + panel_w, gy), fill=(27, 34, 43), width=1)
        draw.rectangle((margin - 7, header - 7, margin + panel_w + 7, header + panel_h + 7), outline=(45, 56, 68), width=2)
        scaled = native.resize((panel_w, panel_h), Image.Resampling.NEAREST)
        canvas.paste(scaled, (margin, header), scaled)
        accent = (247, 190, 72) if key == "gold" else (92, 225, 232)
        draw.text((margin, 12), "护符切换 · 状态示意", font=font(FONT_CN_BOLD, 19), fill=(238, 241, 235))
        tag = "正极" if key == "gold" else "负极"
        draw.text((canvas.width - margin - 44, 16), tag, font=font(FONT_CN_BOLD, 15), fill=accent)
        draw.text((margin, header + panel_h + 10), "本地合成 · 非 Godot 实测 · 姿势固定 idle #0", font=font(FONT_CN, 12), fill=(159, 178, 186))
        frames.append(canvas.quantize(colors=128, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE))
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[700, 700, 700, 700], loop=0, disposal=2, optimize=True)


def preview_preserves_character(character_frame: Image.Image, talismans: dict, glows: dict) -> bool:
    """除护符 5x5 叠放区外，角色原有像素必须保持完全不变。"""
    body = character_frame.crop((32, 30, 96, 94))
    bbox = (
        TALISMAN_TOP_LEFT[0] - 32,
        TALISMAN_TOP_LEFT[1] - 30,
        TALISMAN_TOP_LEFT[0] - 32 + 5,
        TALISMAN_TOP_LEFT[1] - 30 + 5,
    )
    for key in ("gold", "cyan"):
        native = compose_chest_preview(character_frame, talismans[key], glows[key][2])
        for y in range(64):
            for x in range(64):
                if body.getpixel((x, y))[3] == 0:
                    continue
                if bbox[0] <= x < bbox[2] and bbox[1] <= y < bbox[3]:
                    continue
                if native.getpixel((x, y)) != body.getpixel((x, y)):
                    return False
    return True


def verify_assets(talismans: dict, glows: dict, rings: dict, sheet_sizes: dict, talisman_bbox: tuple[int, int, int, int], character_frame: Image.Image) -> dict:
    result = {}
    # 正负 alpha 形状一致
    result["talisman_same_alpha"] = talismans["gold"].getchannel("A").tobytes() == talismans["cyan"].getchannel("A").tobytes()
    result["glow_same_alpha"] = all(
        glows["gold"][i].getchannel("A").tobytes() == glows["cyan"][i].getchannel("A").tobytes()
        for i in range(4)
    )
    result["ring_same_alpha"] = all(
        rings["gold"][i].getchannel("A").tobytes() == rings["cyan"][i].getchannel("A").tobytes()
        for i in range(4)
    )
    result["talisman_alpha_nonempty"] = all(t.getchannel("A").getbbox() is not None for t in talismans.values())
    result["glow_alpha_nonempty"] = all(g.getchannel("A").getbbox() is not None for arr in glows.values() for g in arr)
    result["ring_alpha_nonempty"] = all(r.getchannel("A").getbbox() is not None for arr in rings.values() for r in arr)
    result["talisman_size"] = list(talismans["gold"].size)
    result["talisman_opaque_pixels"] = sum(
        1 for y in range(5) for x in range(5) if talismans["gold"].getpixel((x, y))[3] > 0
    )
    result["talisman_core_pixels"] = sum(
        1 for y in range(5) for x in range(5) if talismans["gold"].getpixel((x, y)) == PALETTES["gold"]["core"]
    )
    result["sheet_frame_division"] = {
        "glow_gold": [sheet_sizes["glow_gold"][0] / 11, sheet_sizes["glow_gold"][1] / 11],
        "glow_cyan": [sheet_sizes["glow_cyan"][0] / 11, sheet_sizes["glow_cyan"][1] / 11],
        "ring_gold": [sheet_sizes["ring_gold"][0] / 24, sheet_sizes["ring_gold"][1] / 24],
        "ring_cyan": [sheet_sizes["ring_cyan"][0] / 24, sheet_sizes["ring_cyan"][1] / 24],
    }
    result["all_sheets_divisible"] = all(
        all(v.is_integer() for v in values) for values in result["sheet_frame_division"].values()
    )
    result["ring_center_consistent"] = all(
        all(
            (
                (frame.getchannel("A").getbbox()[0] + frame.getchannel("A").getbbox()[2] - 1) / 2,
                (frame.getchannel("A").getbbox()[1] + frame.getchannel("A").getbbox()[3] - 1) / 2,
            ) == RING_CENTER
            for frame in arr
        )
        for arr in rings.values()
    )
    result["ring_final_frame_visible"] = all(
        frame.getchannel("A").getextrema()[1] >= 120 for arr in rings.values() for frame in arr
    )
    result["ring_corners_transparent"] = all(
        r.getpixel((0, 0))[3] == 0 and r.getpixel((r.width - 1, 0))[3] == 0
        and r.getpixel((0, r.height - 1))[3] == 0 and r.getpixel((r.width - 1, r.height - 1))[3] == 0
        for arr in rings.values() for r in arr
    )
    result["effect_corners_transparent"] = all(
        image.getpixel((0, 0))[3] == 0 and image.getpixel((image.width - 1, 0))[3] == 0
        and image.getpixel((0, image.height - 1))[3] == 0 and image.getpixel((image.width - 1, image.height - 1))[3] == 0
        for image in list(talismans.values()) + [g for arr in glows.values() for g in arr] + [r for arr in rings.values() for r in arr]
    )
    result["talisman_preview_bbox"] = list(talisman_bbox)
    result["preview_preserves_character_outside_talisman"] = preview_preserves_character(character_frame, talismans, glows)
    result["sheet_sizes"] = sheet_sizes
    return result


def main() -> None:
    if not CHARACTER_SHEET.exists():
        raise SystemExit(f"找不到角色表: {CHARACTER_SHEET}")
    source = Image.open(CHARACTER_SHEET).convert("RGBA")
    if source.width < (PREVIEW_FRAME + 1) * FRAME_SIZE:
        raise SystemExit("角色表宽度不足，无法读取指定帧")
    character_frame = source.crop((PREVIEW_FRAME * FRAME_SIZE, 0, (PREVIEW_FRAME + 1) * FRAME_SIZE, FRAME_SIZE))
    actual_bbox = character_frame.getchannel("A").getbbox()
    if not actual_bbox:
        raise SystemExit("idle #0 没有可见像素")

    talismans = {key: make_talisman(pal) for key, pal in PALETTES.items()}
    glows = {key: [make_glow_frame(pal, i) for i in range(4)] for key, pal in PALETTES.items()}
    rings = {key: [ring_frame(pal, i) for i in range(4)] for key, pal in PALETTES.items()}

    save_png(talismans["gold"], "talisman_gold.png")
    save_png(talismans["cyan"], "talisman_cyan.png")
    glow_sheets = {}
    for key in ("gold", "cyan"):
        sheet = pasted_sheet(glows[key])
        glow_sheets[key] = sheet
        save_png(sheet, f"glow_{key}_4f.png")
    ring_sheets = {}
    for key in ("gold", "cyan"):
        sheet = pasted_sheet(rings[key])
        ring_sheets[key] = sheet
        save_png(sheet, f"switch_ring_{key}_4f.png")

    compare, gold_panel, cyan_panel = make_compare_preview(character_frame, talismans, glows)
    save_png(compare.convert("RGB"), "preview_chest_compare.png")
    save_png(gold_panel.convert("RGB"), "preview_chest_gold.png")
    save_png(cyan_panel.convert("RGB"), "preview_chest_cyan.png")

    contact = make_contact_sheet(talismans, glows, rings)
    save_png(contact.convert("RGB"), "effects_contact_sheet.png")

    make_gif(character_frame, talismans, glows, HERE / "preview_polarity_switch.gif")

    sheet_sizes = {
        "glow_gold": list(glow_sheets["gold"].size),
        "glow_cyan": list(glow_sheets["cyan"].size),
        "ring_gold": list(ring_sheets["gold"].size),
        "ring_cyan": list(ring_sheets["cyan"].size),
    }
    checks = verify_assets(talismans, glows, rings, sheet_sizes, (TALISMAN_TOP_LEFT[0], TALISMAN_TOP_LEFT[1], TALISMAN_TOP_LEFT[0] + 5, TALISMAN_TOP_LEFT[1] + 5), character_frame)

    manifest = {
        "name": "星核旅人 · 胸前极性护符",
        "version": 1,
        "generated_by": "generate_talisman_assets.py (Pillow, 本次原创程序化像素)",
        "character_reference": {
            "file": "individual_sheets/male_hero-idle.png",
            "frame_index": PREVIEW_FRAME,
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "visible_bbox": list(actual_bbox),
            "sprite_anchor": list(SPRITE_ANCHOR),
            "chest_pixel_index": list(CHEST_ANCHOR),
            "chest_pixel_center": [CHEST_ANCHOR[0] + 0.5, CHEST_ANCHOR[1] + 0.5],
            "asset_top_left_px": {
                "talisman": list(TALISMAN_TOP_LEFT),
                "glow": [CHEST_ANCHOR[0] - GLOW_SIZE // 2, CHEST_ANCHOR[1] - GLOW_SIZE // 2],
                "switch_ring": [CHEST_ANCHOR[0] - RING_SIZE // 2, CHEST_ANCHOR[1] - RING_SIZE // 2]
            },
            "recommended_centered": False,
            "node_position_relative_frame_center_px": {
                "talisman": [TALISMAN_TOP_LEFT[0] - SPRITE_ANCHOR[0], TALISMAN_TOP_LEFT[1] - SPRITE_ANCHOR[1]],
                "glow": [CHEST_ANCHOR[0] - GLOW_SIZE // 2 - SPRITE_ANCHOR[0], CHEST_ANCHOR[1] - GLOW_SIZE // 2 - SPRITE_ANCHOR[1]],
                "switch_ring": [CHEST_ANCHOR[0] - RING_SIZE // 2 - SPRITE_ANCHOR[0], CHEST_ANCHOR[1] - RING_SIZE // 2 - SPRITE_ANCHOR[1]]
            },
            "note": "预览固定 idle #0；特效精灵建议 centered=false，以整数 top-left 叠放，避免半像素。转身、跑跳等动作需后续按帧单独配置，本包不声称已实现逐帧跟踪。"
        },
        "assets": {
            "talisman_gold": {
                "file": "talisman_gold.png", "size": [5, 5], "frames": 1, "color": "warm gold", "alpha": "transparent", "use": "Sprite2D, centered=false, above character"
            },
            "talisman_cyan": {
                "file": "talisman_cyan.png", "size": [5, 5], "frames": 1, "color": "cool cyan", "alpha": "transparent", "use": "Sprite2D, centered=false, above character"
            },
            "glow_gold": {
                "sheet": "glow_gold_4f.png", "sheet_size": sheet_sizes["glow_gold"], "frame_size": [11, 11], "frame_count": 4, "fps": 8, "duration_ms": 500, "loop": True, "use": "AnimatedSprite2D/Sprite2D, horizontal frames, centered=false, z below character; no bloom/shader"
            },
            "glow_cyan": {
                "sheet": "glow_cyan_4f.png", "sheet_size": sheet_sizes["glow_cyan"], "frame_size": [11, 11], "frame_count": 4, "fps": 8, "duration_ms": 500, "loop": True, "use": "AnimatedSprite2D/Sprite2D, horizontal frames, centered=false, z below character; no bloom/shader"
            },
            "switch_ring_gold": {
                "sheet": "switch_ring_gold_4f.png", "sheet_size": sheet_sizes["ring_gold"], "frame_size": [24, 24], "frame_count": 4, "fps": 20, "duration_ms": 200, "loop": False, "use": "AnimatedSprite2D/Sprite2D one-shot, centered=false"
            },
            "switch_ring_cyan": {
                "sheet": "switch_ring_cyan_4f.png", "sheet_size": sheet_sizes["ring_cyan"], "frame_size": [24, 24], "frame_count": 4, "fps": 20, "duration_ms": 200, "loop": False, "use": "AnimatedSprite2D/Sprite2D one-shot, centered=false"
            }
        },
        "palette_note": "两种极性的 talisman / glow / ring alpha 形状完全一致，仅调色不同；可用脚本 PALETTES 重制。",
        "checks": checks
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("生成完成:", HERE)
    for p in sorted(HERE.iterdir()):
        if p.is_file() and p.name != "README.md":
            print(f"  {p.name}  {p.stat().st_size} bytes")
    print("checks:", json.dumps(checks, ensure_ascii=False))


if __name__ == "__main__":
    main()
