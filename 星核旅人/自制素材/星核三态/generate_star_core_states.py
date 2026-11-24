#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
星核旅人 · 星核三态素材生成器（锁定原紫 / 正极金 / 负极青）
------------------------------------------------------------
来源：Frakassets "Free Shiny Gem Round" 的 16px、0d（正面）、12 帧彩色表。
本脚本只读取源表，不修改它。

输出两类兼容资产：
  1. 既有 16×16 静帧（第 0 帧裁切），保持旧文件路径和 RGBA 不变；
  2. 新增 192×16 三态 12 帧表：锁定表直接复制源表（逐像素原紫），
     正/负表按既有 HSV 方法逐帧调色。alpha、每帧位置、16×16 画布不变。
     不读取 _normal 法线图，不放大到 32px。

运行（项目指定环境）:
    D:\\minic\\envs\\2024212971\\python.exe generate_star_core_states.py

输出:
    基础场景原型/assets/star_core/star_core_locked.png
    基础场景原型/assets/star_core/star_core_positive.png
    基础场景原型/assets/star_core/star_core_negative.png
    基础场景原型/assets/star_core/star_core_locked_12f.png
    基础场景原型/assets/star_core/star_core_positive_12f.png
    基础场景原型/assets/star_core/star_core_negative_12f.png
    本目录同名备份 PNG、静帧/动画预览、manifest.json

动画播放参数由 Godot 组件负责，默认 12 FPS；本脚本只产出透明帧表。
"""

from __future__ import annotations

import colorsys
import hashlib
import json
import math
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parents[1]
SOURCE_SHEET = (
    PROJECT_ROOT
    / "素材库"
    / "古遗迹候选"
    / "03_star_core_gem"
    / "extracted"
    / "free_gem_round_frakassets"
    / "gem_round_16x16_12f_0d.png"
)
PROJECT_ASSET_DIR = PROJECT_ROOT / "基础场景原型" / "assets" / "star_core"
TALISMAN_DIR = PROJECT_ROOT / "自制素材" / "护符特效"

FRAME_SIZE = 16
FRAME_COUNT = 12
FRAME_INDEX = 0  # 12 帧中不透明像素最多（208），正面面积最大。
SHEET_SIZE = (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE)
ANIMATION_FPS = 12

STATIC_FILES = {
    "locked": "star_core_locked.png",
    "positive": "star_core_positive.png",
    "negative": "star_core_negative.png",
}
ANIMATED_FILES = {
    "locked": "star_core_locked_12f.png",
    "positive": "star_core_positive_12f.png",
    "negative": "star_core_negative_12f.png",
}

SOURCE_ATTRIBUTION = (
    'Free Shiny Gem "Round" by Frakassets, CC BY 4.0, '
    "https://frakassets.itch.io/free-shiny-gem-round"
)
SOURCE_URL = "https://frakassets.itch.io/free-shiny-gem-round"
LICENSE_URL = "https://creativecommons.org/licenses/by/4.0/"

# 参考护符亮色：#f4cd63 / #5fe1e6。色相重映射后，源表最常见的中亮宝石色
# (233,155,247) 分别映射到约 #f2c75b / #5ddfed，保留金色/青色的高光与阴影。
POSITIVE = {
    "hue_deg": 43.0,
    "sat_gamma": 0.62,
    "sat_scale": 1.15,
    "min_sat": 0.22,
    "value_scale": 0.98,
    "outline_tint": (72, 41, 17),
    "outline_mix": 0.45,
}
NEGATIVE = {
    "hue_deg": 186.0,
    "sat_gamma": 0.62,
    "sat_scale": 1.12,
    "min_sat": 0.20,
    "value_scale": 0.96,
    "outline_tint": (9, 43, 53),
    "outline_mix": 0.45,
}

REFERENCE_ACCENTS = {
    "positive": (0xF4, 0xCD, 0x63),
    "negative": (0x5F, 0xE1, 0xE6),
}

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


def lum709(rgb: tuple[int, int, int]) -> float:
    return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]


def rgb_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> float:
    return math.sqrt(sum((int(a[i]) - int(b[i])) ** 2 for i in range(3)))


def opaque_count(image: Image.Image) -> int:
    return sum(1 for value in image.getchannel("A").tobytes() if value > 0)


def border_counts(image: Image.Image) -> dict:
    alpha = image.getchannel("A")
    width, height = image.size
    result = {"top": 0, "bottom": 0, "left": 0, "right": 0}
    for x in range(width):
        if alpha.getpixel((x, 0)) > 0:
            result["top"] += 1
        if alpha.getpixel((x, height - 1)) > 0:
            result["bottom"] += 1
    for y in range(height):
        if alpha.getpixel((0, y)) > 0:
            result["left"] += 1
        if alpha.getpixel((width - 1, y)) > 0:
            result["right"] += 1
    return result


def is_outline_pixel(rgb: tuple[int, int, int], alpha: int) -> bool:
    """源表暗轮廓为 5 级中性灰（value 0.02~0.19）；宝石色 value 均 >0.9。"""
    if alpha == 0:
        return False
    _, _, value = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb))
    return value < 0.50


def map_color(rgb: tuple[int, int, int], params: dict) -> tuple[int, int, int]:
    """保持 alpha 与明暗层级，仅重映射色相/饱和度；中性暗轮廓做轻微染色。"""
    _, saturation, value = colorsys.rgb_to_hsv(*(channel / 255 for channel in rgb))
    if value < 0.50:
        mix = params["outline_mix"]
        tint = params["outline_tint"]
        return tuple(
            max(0, min(255, round(rgb[i] * (1.0 - mix) + tint[i] * mix)))
            for i in range(3)
        )
    out_sat = min(
        1.0,
        max((saturation ** params["sat_gamma"]) * params["sat_scale"], params["min_sat"]),
    )
    out_val = min(1.0, value * params["value_scale"])
    out = colorsys.hsv_to_rgb(params["hue_deg"] / 360.0, out_sat, out_val)
    return tuple(max(0, min(255, round(channel * 255))) for channel in out)


def recolor(image: Image.Image, params: dict) -> Image.Image:
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = image.getpixel((x, y))
            if a == 0:
                result.putpixel((x, y), (0, 0, 0, 0))
                continue
            rr, gg, bb = map_color((r, g, b), params)
            result.putpixel((x, y), (rr, gg, bb, a))
    return result


def recolor_sheet(sheet: Image.Image, params: dict) -> Image.Image:
    """Recolour every 16x16 frame independently; alpha and frame slots untouched."""
    if sheet.size != SHEET_SIZE:
        raise ValueError(f"sheet size {sheet.size}, expected {SHEET_SIZE}")
    result = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for index in range(FRAME_COUNT):
        box = (index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE)
        result.paste(recolor(sheet.crop(box), params), (index * FRAME_SIZE, 0))
    return result


def sheet_frame(sheet: Image.Image, index: int) -> Image.Image:
    box = (index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE)
    return sheet.crop(box)


def frame_bboxes(sheet: Image.Image) -> list:
    boxes = []
    for index in range(FRAME_COUNT):
        bbox = sheet_frame(sheet, index).getchannel("A").getbbox()
        boxes.append(list(bbox) if bbox is not None else None)
    return boxes


def frame_alpha_bytes(sheet: Image.Image) -> list[bytes]:
    return [sheet_frame(sheet, index).getchannel("A").tobytes() for index in range(FRAME_COUNT)]


def frame_opaque_counts(sheet: Image.Image) -> list[int]:
    counts = []
    for index in range(FRAME_COUNT):
        frame = sheet.crop((index * FRAME_SIZE, 0, (index + 1) * FRAME_SIZE, FRAME_SIZE))
        counts.append(opaque_count(frame))
    return counts


def colored_pixels(image: Image.Image) -> list[tuple[int, int, int]]:
    pixels = []
    for _, color in image.getcolors(FRAME_SIZE * FRAME_SIZE):
        r, g, b, a = color
        if a > 0 and not is_outline_pixel((r, g, b), a):
            pixels.append((r, g, b))
    return pixels


def mean_hue(image: Image.Image) -> float:
    sx = sy = weight_sum = 0.0
    for r, g, b in colored_pixels(image):
        hue, saturation, _ = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        weight = max(saturation, 0.05)
        angle = hue * 2.0 * math.pi
        sx += math.cos(angle) * weight
        sy += math.sin(angle) * weight
        weight_sum += weight
    return math.degrees(math.atan2(sy / weight_sum, sx / weight_sum)) % 360.0


def hue_distance(a: float, b: float) -> float:
    diff = abs(a - b) % 360.0
    return min(diff, 360.0 - diff)


def analyze_shading(source_frame: Image.Image, target: Image.Image, params: dict) -> dict:
    source_tones = []
    for count, color in source_frame.getcolors(FRAME_SIZE * FRAME_SIZE):
        r, g, b, a = color
        if a > 0 and not is_outline_pixel((r, g, b), a):
            source_tones.append(((r, g, b), count))
    source_tones.sort(key=lambda item: lum709(item[0]))
    outputs = [map_color(rgb, params) for rgb, _ in source_tones]
    out_lums = [lum709(rgb) for rgb in outputs]
    monotonic = all(out_lums[i] < out_lums[i + 1] for i in range(len(out_lums) - 1))
    return {
        "source_level_count": len(source_tones),
        "output_level_count": len(set(outputs)),
        "monotonic_luminance": monotonic,
        "source_luminance": [round(lum709(rgb), 2) for rgb, _ in source_tones],
        "output_luminance": [round(value, 2) for value in out_lums],
        "source_tones": [list(rgb) for rgb, _ in source_tones],
        "output_tones": [list(rgb) for rgb in outputs],
    }


def most_common_body_tone(source_frame: Image.Image) -> tuple[tuple[int, int, int], int]:
    candidates = []
    for count, color in source_frame.getcolors(FRAME_SIZE * FRAME_SIZE):
        r, g, b, a = color
        if a > 0 and not is_outline_pixel((r, g, b), a):
            candidates.append(((r, g, b), count))
    return max(candidates, key=lambda item: (item[1], item[0]))


def draw_checker(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], cell: int) -> None:
    x0, y0, x1, y1 = box
    colors = ((54, 60, 68), (41, 47, 55))
    for yy in range(y0, y1, cell):
        for xx in range(x0, x1, cell):
            idx = ((xx - x0) // cell + (yy - y0) // cell) % 2
            draw.rectangle(
                (xx, yy, min(xx + cell - 1, x1 - 1), min(yy + cell - 1, y1 - 1)),
                fill=colors[idx],
            )


def make_preview(states: dict) -> Image.Image:
    scale = 14
    sprite_px = FRAME_SIZE * scale
    card_w, card_h = 330, 330
    gap, margin = 24, 40
    header, footer = 104, 150
    width = margin * 2 + card_w * 3 + gap * 2
    height = header + card_h + footer
    canvas = Image.new("RGB", (width, height), (24, 29, 36))
    draw = ImageDraw.Draw(canvas)

    f_title = font(FONT_CN_BOLD, 28)
    f_sub = font(FONT_CN, 14)
    f_state = font(FONT_CN_BOLD, 20)
    f_small = font(FONT_CN, 12)
    f_mono = font(FONT_MONO, 11)
    f_footer = font(FONT_CN, 13)
    f_license = font(FONT_CN, 12)

    draw.text((margin, 20), "星核三态 · 16×16 静帧兼容（第 0 帧）", font=f_title, fill=(238, 241, 235))
    draw.text(
        (margin, 62),
        "锁定原紫（源帧原样） / 正极金 / 负极青  ·  三态 alpha 形状逐像素一致；12 帧动画表另见 animation 预览",
        font=f_sub,
        fill=(156, 174, 184),
    )
    draw.text((width - margin - 116, 28), "STATIC FRAME 0 / 12", font=f_mono, fill=(126, 145, 156))

    panel_meta = (
        ("locked", "锁定 · 原紫", "star_core_locked.png", "源帧逐像素未改，用于仓内锁定", (233, 155, 247)),
        ("positive", "正极 · 金", "star_core_positive.png", "色相 43°，对应护符暖金", (244, 205, 99)),
        ("negative", "负极 · 青", "star_core_negative.png", "色相 186°，对应护符冷青", (95, 225, 230)),
    )
    talismans = {}
    for name in ("positive", "negative"):
        path = TALISMAN_DIR / f"talisman_{'gold' if name == 'positive' else 'cyan'}.png"
        if path.exists():
            talismans[name] = Image.open(path).convert("RGBA")

    for index, (key, title, filename, note, accent) in enumerate(panel_meta):
        x = margin + index * (card_w + gap)
        y = header
        draw.rounded_rectangle((x, y, x + card_w, y + card_h), radius=6, fill=(31, 38, 47), outline=(52, 64, 76), width=1)
        draw.rectangle((x + 1, y + 1, x + card_w - 1, y + 4), fill=accent)
        draw_checker(draw, (x + 53, y + 18, x + 53 + sprite_px, y + 18 + sprite_px), 14)
        draw.rectangle((x + 52, y + 17, x + 53 + sprite_px, y + 18 + sprite_px), outline=(70, 82, 94), width=1)

        sprite = states[key].resize((sprite_px, sprite_px), Image.Resampling.NEAREST)
        canvas.paste(sprite, (x + 53, y + 18), sprite)
        draw.text((x + 16, y + 258), title, font=f_state, fill=accent)
        draw.text((x + 16, y + 286), filename, font=f_mono, fill=(176, 190, 198))
        draw.text((x + 16, y + 304), note, font=f_small, fill=(132, 151, 162))

        # 原生 1× 尺寸，方便检查实际像素可读性。
        draw.text((x + 250, y + 262), "1×", font=f_small, fill=(126, 145, 156))
        canvas.paste(states[key], (x + 292, y + 254), states[key])

        if key in talismans:
            tal = talismans[key]
            tal_big = tal.resize((tal.width * 8, tal.height * 8), Image.Resampling.NEAREST)
            canvas.paste(tal_big, (x + 284, y + 22), tal_big)
            draw.text((x + 287, y + 66), "护符", font=f_small, fill=(126, 145, 156))

    draw.line((margin, height - footer + 2, width - margin, height - footer + 2), fill=(49, 60, 72), width=1)
    lines = (
        "源：gem_round_16x16_12f_0d.png · 第 0 帧 / 共 12 帧 · 16×16 · 原紫锁定态逐像素一致",
        "调色：HSV 色相 → 金 43° / 青 186°，保留 11 级明暗与 44 个暗轮廓像素；参考 #f4cd63 / #5fe1e6",
        "极性符号由组件/UI 层叠加，未烘焙进 PNG；本图是本地 NEAREST 像素合成预览，不是 Godot 引擎截图。",
        "锁定 208 个不透明像素；三态轮廓、非透明像素数一致；无 32px、无法线图。动画表为 12 帧 / 12 FPS。",
    )
    y = height - footer + 18
    for line in lines:
        draw.text((margin, y), line, font=f_footer, fill=(162, 178, 188))
        y += 24
    draw.text(
        (margin, y + 2),
        'Free Shiny Gem "Round" by Frakassets · CC BY 4.0 · 修改：截取第 0 帧、金/青调色',
        font=f_license,
        fill=(126, 145, 156),
    )
    return canvas


def make_animation_preview(sheets: dict) -> Image.Image:
    """Local NEAREST contact sheet: all 12 frames of all three states."""
    scale = 8
    cell = FRAME_SIZE * scale
    gap = 6
    margin = 28
    header = 86
    row_gap = 22
    row_label_w = 150
    footer = 88
    width = margin * 2 + row_label_w + FRAME_COUNT * (cell + gap) - gap
    height = header + 3 * (cell + row_gap) + footer
    canvas = Image.new("RGB", (width, height), (24, 29, 36))
    draw = ImageDraw.Draw(canvas)

    f_title = font(FONT_CN_BOLD, 26)
    f_sub = font(FONT_CN, 13)
    f_row = font(FONT_CN_BOLD, 16)
    f_small = font(FONT_CN, 11)
    f_mono = font(FONT_MONO, 10)

    draw.text((margin, 16), "星核三态 · 192×16 / 12 帧动画表", font=f_title, fill=(238, 241, 235))
    draw.text(
        (margin, 52),
        "锁定原紫（源表逐像素原样） / 正极金 / 负极青  ·  每帧 16×16，alpha 与位置逐帧一致  ·  默认 12 FPS",
        font=f_sub,
        fill=(156, 174, 184),
    )

    rows = (
        ("locked", "锁定 · 原紫", (200, 167, 242)),
        ("positive", "正极 · 金", (244, 205, 99)),
        ("negative", "负极 · 青", (95, 225, 230)),
    )
    for row, (key, title, accent) in enumerate(rows):
        y = header + row * (cell + row_gap)
        x0 = margin
        draw.text((x0, y + 2), title, font=f_row, fill=accent)
        draw.text((x0, y + 26), f"{ANIMATED_FILES[key]}", font=f_mono, fill=(176, 190, 198))
        draw.text((x0, y + 42), f"{ANIMATION_FPS} FPS LOOP", font=f_small, fill=(132, 151, 162))
        draw.text((x0, y + 58), f"{FRAME_COUNT} FRAMES", font=f_small, fill=(132, 151, 162))
        for index in range(FRAME_COUNT):
            x = margin + row_label_w + index * (cell + gap)
            checker = Image.new("RGB", (cell, cell))
            check = ImageDraw.Draw(checker)
            cell_size = 8
            for yy in range(0, cell, cell_size):
                for xx in range(0, cell, cell_size):
                    on = ((xx // cell_size) + (yy // cell_size)) % 2 == 0
                    check.rectangle(
                        (xx, yy, xx + cell_size - 1, yy + cell_size - 1),
                        fill=(54, 60, 68) if on else (41, 47, 55),
                    )
            frame = sheet_frame(sheets[key], index).resize(
                (cell, cell), Image.Resampling.NEAREST
            )
            checker.paste(frame, (0, 0), frame)
            canvas.paste(checker, (x, y))
            draw.rectangle((x, y, x + cell, y + cell), outline=(66, 78, 90), width=1)
            draw.text((x + 2, y + cell + 2), f"{index:02d}", font=f_mono, fill=(126, 145, 156))

    y = height - footer + 12
    lines = (
        "源：Frakassets Free Shiny Gem \"Round\" 16px / 0d / 12f · CC BY 4.0 · 修改：三态逐帧调色/复制。",
        "本图是 Python NEAREST 像素合成的素材检查图，不是 Godot 引擎截图；极性符号由组件另绘，未烘焙。",
        "动画使用完整源表，不读取 _normal，不放大画布；实际显示尺寸固定 16×16，不随薄边帧缩放。",
    )
    for line in lines:
        draw.text((margin, y), line, font=f_small, fill=(162, 178, 188))
        y += 20
    return canvas


def main() -> None:
    if not SOURCE_SHEET.exists():
        raise SystemExit(f"找不到源表: {SOURCE_SHEET}")

    source_hash_before = sha256_file(SOURCE_SHEET)
    sheet = Image.open(SOURCE_SHEET).convert("RGBA")
    if sheet.size != (FRAME_SIZE * FRAME_COUNT, FRAME_SIZE):
        raise SystemExit(f"源表尺寸异常: {sheet.size}，预期 {(FRAME_SIZE * FRAME_COUNT, FRAME_SIZE)}")

    counts = frame_opaque_counts(sheet)
    fullest = counts.index(max(counts))
    if fullest != FRAME_INDEX:
        raise SystemExit(f"源表最饱满帧为 {fullest}，与记录的 FRAME_INDEX={FRAME_INDEX} 不符")

    source_frame = sheet.crop(
        (FRAME_INDEX * FRAME_SIZE, 0, (FRAME_INDEX + 1) * FRAME_SIZE, FRAME_SIZE)
    )
    if source_frame.getchannel("A").getbbox() is None:
        raise SystemExit("选定帧没有可见像素")

    locked = source_frame.copy()
    positive = recolor(source_frame, POSITIVE)
    negative = recolor(source_frame, NEGATIVE)

    # 12-frame sheets. Locked is a byte-for-byte copy of the source sheet so its
    # RGBA (and even encoding) stays identical; gold/cyan are recoloured frame by
    # frame with the same HSV method used for the static files.
    locked_sheet = sheet.copy()
    positive_sheet = recolor_sheet(sheet, POSITIVE)
    negative_sheet = recolor_sheet(sheet, NEGATIVE)

    PROJECT_ASSET_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "locked": (STATIC_FILES["locked"], locked),
        "positive": (STATIC_FILES["positive"], positive),
        "negative": (STATIC_FILES["negative"], negative),
    }
    project_paths = {}
    for key, (filename, image) in outputs.items():
        target = PROJECT_ASSET_DIR / filename
        image.save(target, "PNG", optimize=True)
        backup = HERE / filename
        shutil.copy2(target, backup)
        project_paths[key] = target

    animated_outputs = {
        "locked": (ANIMATED_FILES["locked"], locked_sheet),
        "positive": (ANIMATED_FILES["positive"], positive_sheet),
        "negative": (ANIMATED_FILES["negative"], negative_sheet),
    }
    animated_paths = {}
    for key, (filename, image) in animated_outputs.items():
        target = PROJECT_ASSET_DIR / filename
        if key == "locked":
            shutil.copy2(SOURCE_SHEET, target)
        else:
            image.save(target, "PNG", optimize=True)
        backup = HERE / filename
        shutil.copy2(target, backup)
        animated_paths[key] = target

    # 从磁盘重新读取，验证保存后的实际 RGBA，而不是内存中的图像。
    saved = {
        key: Image.open(PROJECT_ASSET_DIR / filename).convert("RGBA")
        for key, (filename, _) in outputs.items()
    }
    saved_sheets = {
        key: Image.open(PROJECT_ASSET_DIR / filename).convert("RGBA")
        for key, (filename, _) in animated_outputs.items()
    }

    source_hash_after = sha256_file(SOURCE_SHEET)
    alpha_locked = saved["locked"].getchannel("A").tobytes()
    alpha_positive = saved["positive"].getchannel("A").tobytes()
    alpha_negative = saved["negative"].getchannel("A").tobytes()
    source_alpha = source_frame.getchannel("A").tobytes()
    alpha_equal = alpha_locked == alpha_positive == alpha_negative
    locked_exact = saved["locked"].tobytes() == source_frame.tobytes()
    sizes_ok = all(image.size == (FRAME_SIZE, FRAME_SIZE) for image in saved.values())
    modes_ok = all(image.mode == "RGBA" for image in saved.values())
    opaque_counts = {key: opaque_count(image) for key, image in saved.items()}
    opaque_equal = len(set(opaque_counts.values())) == 1
    bboxes = {key: list(image.getchannel("A").getbbox()) for key, image in saved.items()}
    border = {key: border_counts(image) for key, image in saved.items()}

    hue_locked = mean_hue(saved["locked"])
    hue_positive = mean_hue(saved["positive"])
    hue_negative = mean_hue(saved["negative"])
    shift_positive = hue_distance(hue_locked, hue_positive)
    shift_negative = hue_distance(hue_locked, hue_negative)

    shading_positive = analyze_shading(source_frame, saved["positive"], POSITIVE)
    shading_negative = analyze_shading(source_frame, saved["negative"], NEGATIVE)

    # 暗轮廓：源帧 44 px 中性暗色，调色后仍应在暗部。
    outline_positions = [
        (x, y)
        for y in range(FRAME_SIZE)
        for x in range(FRAME_SIZE)
        if is_outline_pixel(source_frame.getpixel((x, y))[:3], source_frame.getpixel((x, y))[3])
    ]
    outline_counts = {key: len(outline_positions) for key in saved}
    outline_max_lum = {}
    for key, image in saved.items():
        outline_max_lum[key] = max(
            lum709(image.getpixel((x, y))[:3]) for x, y in outline_positions
        )

    body_source, body_count = most_common_body_tone(source_frame)
    body_positive = map_color(body_source, POSITIVE)
    body_negative = map_color(body_source, NEGATIVE)
    accent_distance = {
        "positive": round(rgb_distance(body_positive, REFERENCE_ACCENTS["positive"]), 2),
        "negative": round(rgb_distance(body_negative, REFERENCE_ACCENTS["negative"]), 2),
    }

    unique_rgb = {
        key: len([color for _, color in image.getcolors(FRAME_SIZE * FRAME_SIZE) if color[3] > 0])
        for key, image in saved.items()
    }
    corners_transparent = all(
        image.getpixel((0, 0))[3] == 0
        and image.getpixel((FRAME_SIZE - 1, 0))[3] == 0
        and image.getpixel((0, FRAME_SIZE - 1))[3] == 0
        and image.getpixel((FRAME_SIZE - 1, FRAME_SIZE - 1))[3] == 0
        for image in saved.values()
    )
    alpha_binary = all(set(image.getchannel("A").tobytes()) <= {0, 255} for image in saved.values())

    # Animated sheet checks, read back from disk.
    source_alpha_frames = frame_alpha_bytes(sheet)
    source_bboxes = frame_bboxes(sheet)
    sheet_sizes_ok = all(image.size == SHEET_SIZE for image in saved_sheets.values())
    sheet_modes_ok = all(image.mode == "RGBA" for image in saved_sheets.values())
    sheet_alphas = {key: frame_alpha_bytes(image) for key, image in saved_sheets.items()}
    sheet_bboxes = {key: frame_bboxes(image) for key, image in saved_sheets.items()}
    sheet_opaque_counts = {
        key: [opaque_count(sheet_frame(image, index)) for index in range(FRAME_COUNT)]
        for key, image in saved_sheets.items()
    }
    sheet_alpha_equal = all(
        sheet_alphas[key] == source_alpha_frames for key in saved_sheets
    )
    sheet_bbox_equal = all(
        sheet_bboxes[key] == source_bboxes for key in saved_sheets
    )
    sheet_counts_equal = all(
        sheet_opaque_counts[key] == counts for key in saved_sheets
    )
    locked_sheet_exact = saved_sheets["locked"].tobytes() == sheet.tobytes()
    static_matches_sheet_frame_zero = all(
        saved[key].tobytes() == sheet_frame(saved_sheets[key], 0).tobytes()
        for key in saved
    )
    all_frames_visible = all(
        sheet_frame(image, index).getchannel("A").getbbox() is not None
        for image in saved_sheets.values()
        for index in range(FRAME_COUNT)
    )
    sheet_alpha_binary = all(
        set(sheet_frame(image, index).getchannel("A").tobytes()) <= {0, 255}
        for image in saved_sheets.values()
        for index in range(FRAME_COUNT)
    )

    checks = {
        "source_unchanged": source_hash_before == source_hash_after,
        "locked_matches_source_frame_exact_rgba": locked_exact,
        "locked_alpha_matches_source_alpha": alpha_locked == source_alpha,
        "all_sizes_16x16": sizes_ok,
        "all_modes_rgba": modes_ok,
        "alpha_pixels_identical_across_states": alpha_equal,
        "alpha_binary_0_or_255": alpha_binary,
        "opaque_pixels_equal_across_states": opaque_equal,
        "opaque_pixels": opaque_counts["locked"],
        "silhouette_bbox_equal": len({tuple(value) for value in bboxes.values()}) == 1,
        "silhouette_bbox": bboxes["locked"],
        "border_occupancy_equal": len({json.dumps(value, sort_keys=True) for value in border.values()}) == 1,
        "border_occupancy": border["locked"],
        "dark_outline_pixels_44": outline_counts,
        "dark_outline_max_luminance_below_60": all(value < 60 for value in outline_max_lum.values()),
        "dark_outline_max_luminance": {key: round(value, 2) for key, value in outline_max_lum.items()},
        "unique_opaque_rgb": unique_rgb,
        "corner_pixels_transparent": corners_transparent,
        "mean_hue_deg": {
            "locked": round(hue_locked, 2),
            "positive": round(hue_positive, 2),
            "negative": round(hue_negative, 2),
        },
        "hue_shift_deg": {
            "positive": round(shift_positive, 2),
            "negative": round(shift_negative, 2),
        },
        "hue_changed_positively": shift_positive >= 30 and shift_negative >= 30,
        "shading_positive": shading_positive,
        "shading_negative": shading_negative,
        "shading_monotonic_both": (
            shading_positive["monotonic_luminance"] and shading_negative["monotonic_luminance"]
        ),
        "shading_levels_preserved_both": (
            shading_positive["output_level_count"] == shading_positive["source_level_count"]
            and shading_negative["output_level_count"] == shading_negative["source_level_count"]
        ),
        "most_common_body_tone": {
            "source_rgb": list(body_source),
            "source_pixel_count": body_count,
            "positive_rgb": list(body_positive),
            "negative_rgb": list(body_negative),
            "positive_reference_distance_rgb": accent_distance["positive"],
            "negative_reference_distance_rgb": accent_distance["negative"],
        },
        "reference_accents": {
            "positive": "#f4cd63",
            "negative": "#5fe1e6",
        },
        "animation_sheets": {
            "all_sizes_192x16": sheet_sizes_ok,
            "all_modes_rgba": sheet_modes_ok,
            "frame_count": FRAME_COUNT,
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "fps_default": ANIMATION_FPS,
            "locked_sheet_matches_source_sheet_exact_rgba": locked_sheet_exact,
            "alpha_frames_identical_across_states": sheet_alpha_equal,
            "frame_bboxes_identical_across_states": sheet_bbox_equal,
            "frame_opaque_counts_identical_across_states": sheet_counts_equal,
            "opaque_counts_per_frame": sheet_opaque_counts["locked"],
            "static_frame_zero_matches_sheet_frame_zero": static_matches_sheet_frame_zero,
            "all_12_frames_have_visible_pixels": all_frames_visible,
            "alpha_binary_0_or_255_all_frames": sheet_alpha_binary,
            "frame_bboxes": source_bboxes,
            "normal_map_not_read": True,
        },
    }

    preview = make_preview(saved)
    preview_path = HERE / "star_core_states_preview.png"
    preview.save(preview_path, "PNG", optimize=True)

    animation_preview = make_animation_preview(saved_sheets)
    animation_preview_path = HERE / "star_core_animation_sheet_preview.png"
    animation_preview.save(animation_preview_path, "PNG", optimize=True)

    assets_manifest = {}
    project_relative = PROJECT_ASSET_DIR.relative_to(PROJECT_ROOT).as_posix()
    for key, (filename, _) in outputs.items():
        assets_manifest[key] = {
            "file": filename,
            "project_path": f"{project_relative}/{filename}",
            "backup_path": f"自制素材/星核三态/{filename}",
            "size": [FRAME_SIZE, FRAME_SIZE],
            "mode": "RGBA",
            "opaque_pixels": opaque_counts[key],
            "unique_opaque_rgb": unique_rgb[key],
            "sha256": sha256_file(PROJECT_ASSET_DIR / filename),
            "rgba_sha256": sha256_rgba(saved[key]),
        }

    animated_manifest = {}
    for key, (filename, _) in animated_outputs.items():
        animated_manifest[key] = {
            "file": filename,
            "project_path": f"{project_relative}/{filename}",
            "backup_path": f"自制素材/星核三态/{filename}",
            "size": list(SHEET_SIZE),
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "frame_count": FRAME_COUNT,
            "fps_default": ANIMATION_FPS,
            "mode": "RGBA",
            "opaque_pixels_per_frame": sheet_opaque_counts[key],
            "sha256": sha256_file(PROJECT_ASSET_DIR / filename),
            "rgba_sha256": sha256_rgba(saved_sheets[key]),
            "frame_alpha_sha256": [
                hashlib.sha256(alpha).hexdigest()
                for alpha in sheet_alphas[key]
            ],
        }

    manifest = {
        "name": "星核旅人 · 星核三态（锁定原紫 / 正金 / 负青，静帧 + 12 帧）",
        "version": 2,
        "generated_by": "generate_star_core_states.py (Pillow, 色相重映射)",
        "source": {
            "author": "Frakassets",
            "asset": 'Free Shiny Gem "Round"',
            "url": SOURCE_URL,
            "license": "CC BY 4.0",
            "license_url": LICENSE_URL,
            "file": "素材库/古遗迹候选/03_star_core_gem/extracted/free_gem_round_frakassets/gem_round_16x16_12f_0d.png",
            "sha256": source_hash_before,
            "sheet_size": [FRAME_SIZE * FRAME_COUNT, FRAME_SIZE],
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "frame_count": FRAME_COUNT,
            "selected_frame_index": FRAME_INDEX,
            "frame_opaque_counts": counts,
            "selection_reason": "12 帧旋转表中第 0 帧不透明像素最多（208），正面面积最大且适合 16px 识别；未使用 20d、32px 或 _normal 法线图。",
            "selected_frame_rgba_sha256": sha256_rgba(source_frame),
            "unmodified": source_hash_before == source_hash_after,
        },
        "animation": {
            "frame_count": FRAME_COUNT,
            "frame_size": [FRAME_SIZE, FRAME_SIZE],
            "sheet_size": list(SHEET_SIZE),
            "fps_default": ANIMATION_FPS,
            "fps_exportable_range": [1.0, 60.0],
            "display_size": [FRAME_SIZE, FRAME_SIZE],
            "loop": True,
            "note": "Godot 组件默认 12 FPS 循环；每个显示实例仍是 16×16，不随薄边帧缩放。",
        },
        "modifications": [
            "从 16px / 0d / 12 帧彩色表裁切第 0 帧，作为既有静帧锁定态，RGBA 逐像素未改。",
            "新增 192×16 锁定 12 帧表：直接复制源表，12 帧 RGBA 逐像素与源表一致。",
            "正/负态静帧与 12 帧表均用 HSV 色相重映射到金 43° / 青 186°，保留源表各级宝石明暗。",
            "5 个中性暗轮廓颜色按 45% 混入深金 / 深青，保持暗轮廓与剪影。",
            "12 帧表逐帧保留 16×16 画布、alpha 和帧位置；未使用 32px、20d、_normal 法线图，未放大画布。",
        ],
        "assets": assets_manifest,
        "animated_assets": animated_manifest,
        "palette": {
            "positive": {
                **POSITIVE,
                "reference_accent": "#f4cd63",
                "note": "色相 43°，饱和度按源明暗层级重映射，保留高光/阴影；非单色平涂。",
            },
            "negative": {
                **NEGATIVE,
                "reference_accent": "#5fe1e6",
                "note": "色相 186°，饱和度按源明暗层级重映射，保留高光/阴影；非单色平涂。",
            },
        },
        "checks": checks,
        "review_artifacts": {
            "preview": {
                "file": "star_core_states_preview.png",
                "size": list(preview.size),
                "mode": "RGB (opaque composite)",
                "sha256": sha256_file(preview_path),
                "note": "16×16 静帧兼容对比；本地 NEAREST 合成预览，不是游戏截图；叠加的项目自制护符图标仅作配色对照。",
            },
            "animation_preview": {
                "file": "star_core_animation_sheet_preview.png",
                "size": list(animation_preview.size),
                "mode": "RGB (opaque composite)",
                "sha256": sha256_file(animation_preview_path),
                "note": "三态 × 12 帧的本地 NEAREST 素材检查图；不是 Godot 引擎截图，也不代表实际播放速度。",
            },
        },
        "integration": {
            "godot_path": "res://assets/star_core/",
            "files": [STATIC_FILES["locked"], STATIC_FILES["positive"], STATIC_FILES["negative"]],
            "animated_files": [ANIMATED_FILES["locked"], ANIMATED_FILES["positive"], ANIMATED_FILES["negative"]],
            "render": "StarCoreVisual 默认读取 12 帧表，以 AtlasTexture 逐帧显示 16×16；Nearest、Mipmaps Off、12 FPS 可 export。",
            "polarity_symbol": "不在 PNG 内；由组件/UI 层叠加金/青极性符号，避免只靠颜色识别；符号不随帧旋转或镜像。",
            "engine_verification": "由组件 Agent 在 Godot 4.7.2 导入、挂载并运行视觉测试；本生成器只验证 RGBA/alpha 和文件写入。",
        },
        "attribution": SOURCE_ATTRIBUTION,
        "license_note": "三张静帧及三张 12 帧派生 PNG 均为 CC BY 4.0 衍生作品，需保留 Frakassets 署名、许可链接和修改说明。预览是内部评审合成图，含项目自制护符图标，不随本包重新授权，不作为可分发素材。原图未被修改，也未随附原包。",
        "notes": [
            "预览中的棋盘与文字仅用于评审，不属于透明 PNG。",
            "既有三张 PNG 均为 16×16 静帧；新增三张 192×16 表各含 12 帧，不含极性符号、HUD 或引擎配置。",
            "锁定 12 帧表为源表逐字节复制；正/负表只调色，alpha 与每帧位置不变。",
            "本任务未写入 .import；工程目录内 .import 为 Godot 编辑器自动生成。",
            "组件/场景接入、目标文件名以外的文件由开发 Agent 负责。",
        ],
    }
    (HERE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print("生成完成:", HERE)
    print("工程资产:", PROJECT_ASSET_DIR)
    for key, meta in assets_manifest.items():
        print(f"  {key:9s} {meta['file']}  sha256={meta['sha256']}  opaque={meta['opaque_pixels']}")
    for key, meta in animated_manifest.items():
        print(
            f"  {key:9s} {meta['file']}  sha256={meta['sha256']}  "
            f"frames={meta['frame_count']}  per_frame={meta['opaque_pixels_per_frame']}"
        )
    print("selected frame:", FRAME_INDEX, "opaque_counts:", counts)
    print("hue:", checks["mean_hue_deg"], "shift:", checks["hue_shift_deg"])
    print("animation checks:", json.dumps(checks["animation_sheets"], ensure_ascii=False))
    print("preview:", preview_path)
    print("animation preview:", animation_preview_path)


if __name__ == "__main__":
    main()
