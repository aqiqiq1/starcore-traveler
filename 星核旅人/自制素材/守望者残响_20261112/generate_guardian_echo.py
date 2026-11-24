# -*- coding: utf-8 -*-
"""
《星核旅人》古代守望者的残响：48x64 四帧 idle 素材。

仅本地 Pillow 逐像素绘制；无下载、无第三方素材、无付费生成服务。
AI 辅助排布/调色，不是人类手绘；不冒充任何第三方作者或许可。
最终形象仍待协调者视觉验收。
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]          # 星核旅人
ENGINE = ROOT / "基础场景原型"
DOC = ROOT / "自制素材" / "守望者残响_20261112"
OUT = ENGINE / "assets" / "guide_echo_20261112"

W, H = 48, 64
ANCHOR = (24, 60)

# ---- palette: grey-white stone + low-saturation pale purple + warm face ----
OUTLINE = (62, 56, 71)
DEEP = (74, 69, 85)
PUR_D = (92, 85, 104)
PUR = (112, 103, 128)
PUR_L = (138, 126, 153)
STONE_D = (127, 122, 128)
STONE = (168, 163, 165)
STONE_L = (198, 193, 190)
STONE_H = (224, 220, 213)
FACE_D = (107, 90, 85)
FACE = (201, 169, 143)
FACE_L = (230, 199, 169)
EYE = (46, 40, 51)
GLOW = (240, 215, 180)


class Figure:
    def __init__(self) -> None:
        self.im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        self.draw = ImageDraw.Draw(self.im)

    def poly(self, points, fill):
        self.draw.polygon(points, fill=fill + (255,))

    def p(self, x, y, fill, a=255):
        if 0 <= x < W and 0 <= y < H:
            self.im.putpixel((x, y), fill + (a,))


def draw_figure(dy: int = 0, phase: int = 0) -> Image.Image:
    """One 48x64 frame. dy shifts the whole visible body; anchor stays (24,60)."""
    f = Figure()
    y = lambda v: v + dy  # noqa: E731

    # ---------------- body silhouette: asymmetric, three-quarter ----------------
    body = [(25, 14), (28, 15), (30, 18), (31, 21), (31, 25), (30, 28),
            (31, 31), (32, 35), (33, 39), (34, 44), (35, 48), (34, 51),
            (32, 54), (30, 55), (28, 56), (26, 55), (24, 54), (22, 55),
            (20, 53), (18, 51), (17, 48), (18, 44), (19, 41), (19, 37),
            (20, 33), (21, 30), (20, 28), (19, 25), (19, 21), (20, 17),
            (22, 15)]
    f.poly([(x, y(v)) for x, v in body], OUTLINE)

    # ---------------- neck ----------------
    f.poly([(22, 26), (27, 26), (27, 30), (22, 30)], DEEP)
    for yy in (27, 28):
        for xx in (23, 24, 25):
            f.p(xx, y(yy), PUR_D)

    # ---------------- mantle / shoulders ----------------
    mantle = [(15, 29), (24, 28), (28, 29), (33, 30), (34, 33), (32, 35),
              (28, 36), (19, 35), (16, 34), (14, 32)]
    f.poly([(x, y(v)) for x, v in mantle], STONE)
    f.poly([(x, y(v)) for x, v in [(16, 29), (23, 28), (23, 31), (19, 33), (16, 32), (14, 32)]], STONE_L)
    f.poly([(x, y(v)) for x, v in [(27, 29), (33, 30), (34, 33), (32, 35), (28, 36), (27, 33)]], PUR_L)
    f.poly([(x, y(v)) for x, v in [(31, 31), (34, 32), (33, 34), (30, 36), (28, 34)]], PUR)
    for x in range(17, 32):
        if x % 4 != 0:
            f.p(x, y(34), PUR_D)
    for x in range(18, 31, 3):
        f.p(x, y(33), STONE_L)
    for x, yy in [(18, 30), (19, 30), (20, 31), (21, 32)]:
        f.p(x, y(yy), STONE_H if x < 20 else STONE_L)
    # shoulder seams
    for x in range(16, 21):
        f.p(x, y(30), DEEP)
    for x in range(31, 34):
        f.p(x, y(31), DEEP)

    # ---------------- hood ----------------
    hood = [(25, 14), (28, 15), (30, 18), (31, 21), (31, 25), (30, 28),
            (28, 30), (22, 30), (20, 28), (19, 25), (19, 21), (20, 17), (22, 15)]
    f.poly([(x, y(v)) for x, v in hood], STONE_L)
    f.poly([(x, y(v)) for x, v in [(27, 16), (30, 19), (31, 22), (31, 25),
                                    (30, 28), (28, 30), (26, 29), (28, 26),
                                    (28, 21), (27, 18)]], STONE)
    f.poly([(x, y(v)) for x, v in [(29, 21), (31, 24), (30, 28), (28, 30),
                                    (26, 29), (28, 25), (28, 22)]], PUR_L)
    for x, yy in [(24, 15), (25, 15), (24, 16), (25, 16)]:
        f.p(x, y(yy), STONE_H)
    for yy in range(19, 27):
        f.p(20 + (1 if yy > 23 else 0), y(yy), STONE_H if yy % 4 == 0 else STONE)
    for yy in range(20, 29):
        if yy % 3 != 0:
            f.p(29, y(yy), PUR_D)

    # ---------------- face: small front-facing, warm, friendly ----------------
    f.poly([(x, y(v)) for x, v in [(21, 20), (27, 20), (27, 25), (26, 27),
                                    (24, 28), (22, 27), (21, 25)]], FACE_D)
    f.poly([(x, y(v)) for x, v in [(22, 21), (26, 21), (26, 25), (25, 26),
                                    (24, 27), (23, 26), (22, 25)]], FACE)
    # warm forehead, nose bridge, cheeks
    for x, yy in [(23, 21), (24, 21), (23, 22), (24, 22), (24, 23)]:
        f.p(x, y(yy), FACE_L)
    f.p(24, y(22), GLOW)
    f.p(22, y(23), FACE_L); f.p(26, y(23), FACE)
    f.p(23, y(24), FACE); f.p(25, y(24), FACE)
    f.p(24, y(25), FACE_D)
    f.p(24, y(26), FACE_L)
    # two eyes, 1px each, no large glow
    f.p(23, y(23), EYE); f.p(25, y(23), EYE)
    # hood shadow above the face
    for x in range(21, 27):
        f.p(x, y(20), DEEP)
    for x, yy in [(21, 21), (26, 21)]:
        f.p(x, y(yy), DEEP)
    # rim light on the near hood edge
    for x, yy in [(21, 19), (22, 19), (26, 19), (27, 19)]:
        f.p(x, y(yy), STONE_L)

    # ---------------- torso / waist ----------------
    f.poly([(x, y(v)) for x, v in [(19, 32), (30, 32), (30, 36), (29, 40),
                                    (20, 40), (19, 36)]], STONE)
    f.poly([(x, y(v)) for x, v in [(19, 32), (23, 32), (22, 37), (21, 40),
                                    (20, 40), (19, 36)]], STONE_L)
    f.poly([(x, y(v)) for x, v in [(26, 32), (30, 32), (30, 36), (29, 40),
                                    (26, 40), (26, 36)]], PUR_L)
    f.poly([(x, y(v)) for x, v in [(22, 32), (26, 32), (25, 36), (24, 38), (23, 36)]], DEEP)
    f.poly([(x, y(v)) for x, v in [(23, 32), (25, 32), (24, 36)]], PUR_D)
    for x, yy in [(24, 33), (24, 34), (23, 34), (25, 34)]:
        f.p(x, y(yy), STONE_H if yy < 34 else STONE_L)
    # waist sash, stone/purple only
    for x in range(19, 30):
        f.p(x, y(39), PUR_D if x % 3 else DEEP)
    for x, c in [(23, STONE), (24, STONE_L), (25, STONE)]:
        f.p(x, y(39), c)

    # ---------------- cloak skirt: sweeps right ----------------
    skirt = [(19, 40), (30, 40), (31, 44), (33, 47), (34, 50), (33, 53),
             (31, 55), (29, 56), (27, 55), (25, 54), (22, 53), (20, 51),
             (18, 49), (17, 46), (18, 43)]
    f.poly([(x, y(v)) for x, v in skirt], STONE)
    f.poly([(x, y(v)) for x, v in [(19, 40), (23, 40), (22, 45), (22, 49),
                                    (20, 51), (18, 49), (17, 46), (18, 43)]], STONE_L)
    f.poly([(x, y(v)) for x, v in [(26, 40), (30, 40), (31, 44), (33, 47),
                                    (34, 50), (33, 53), (31, 55), (29, 54),
                                    (28, 50), (28, 46)]], PUR_L)
    f.poly([(x, y(v)) for x, v in [(30, 43), (33, 45), (34, 48), (32, 52),
                                    (30, 53), (29, 49), (29, 46)]], PUR)
    # 3 folds following the sweep, no grid
    for x0, y0, y1, slope in [(20, 41, 49, 0.20), (24, 41, 53, 0.10), (28, 42, 52, -0.10)]:
        for yy in range(y0, y1):
            x = round(x0 + slope * (yy - y0))
            if (x + yy) % 13 == 0:
                continue
            f.p(x, y(yy), PUR_D)
            if (yy - y0) % 6 == 0:
                f.p(x - 1, y(yy), STONE_H if x < 25 else STONE_L)
    for x in (18, 19):
        f.p(x, y(47), PUR_D)
    for x in (30, 31):
        f.p(x, y(48), PUR_D)

    # ---------------- left arm / hand (visible) ----------------
    f.poly([(x, y(v)) for x, v in [(14, 30), (19, 29), (19, 33), (18, 36),
                                    (17, 40), (18, 43), (18, 45), (16, 47),
                                    (14, 45), (14, 41), (15, 37), (14, 33)]], OUTLINE)
    f.poly([(x, y(v)) for x, v in [(15, 31), (18, 30), (18, 34), (17, 37),
                                    (16, 41), (17, 44), (17, 45), (15, 46),
                                    (14, 44), (14, 41), (15, 37), (15, 33)]], STONE_L)
    f.poly([(x, y(v)) for x, v in [(17, 32), (18, 33), (17, 37), (16, 41),
                                    (17, 44), (16, 45), (15, 43), (15, 39),
                                    (16, 35), (16, 33)]], STONE)
    # cuff
    for x in (15, 16, 17):
        f.p(x, y(42), DEEP)
    # hand: 3x3 open, clear outline
    f.poly([(x, y(v)) for x, v in [(14, 43), (17, 43), (18, 45), (17, 46),
                                    (15, 47), (13, 46), (13, 44)]], STONE_L)
    f.p(15, y(44), STONE_H); f.p(16, y(44), STONE_H); f.p(16, y(45), STONE)
    f.p(14, y(46), OUTLINE); f.p(17, y(45), OUTLINE)
    # sleeve/body separation: keep the shoulder connected, open a 1px
    # background gap below it so the arm reads as an arm, not a fold.
    for yy in range(33, 35):
        f.p(19, y(yy), PUR_D)
    for yy in range(35, 42):
        f.p(19, y(yy), (0, 0, 0), 0)

    # ---------------- right hand hint / cloak fold ----------------
    for x, yy in [(29, 42), (30, 43), (30, 44), (31, 42)]:
        f.p(x, y(yy), PUR_D)
    f.p(28, y(44), STONE_D); f.p(31, y(45), DEEP)

    # ---------------- tattered hem / echo ----------------
    for x, yy in [(19, 50), (20, 52), (22, 52), (23, 51), (25, 53), (26, 52),
                  (28, 54), (29, 53), (31, 54), (32, 52), (34, 49)]:
        f.p(x, y(yy), OUTLINE)
    for x, yy, c in [(20, 52, STONE_D), (22, 53, STONE), (24, 54, STONE_D),
                     (26, 55, STONE_L), (27, 54, PUR_L), (29, 55, PUR),
                     (31, 53, STONE_D), (33, 51, PUR_L)]:
        f.p(x, y(yy), c)
    # long wisps
    for x, yy, c, a in [(24, 55, PUR_L, 180), (26, 57, STONE_L, 150),
                        (21, 54, STONE_D, 150), (32, 53, PUR_L, 150)]:
        f.p(x, y(yy), c, a)
    # sparse edge fragments; phase toggles a few, not the whole body
    frags0 = [(12, 42, PUR_L, 110), (11, 43, STONE_L, 60),
              (13, 48, PUR_L, 90), (36, 42, PUR_L, 80),
              (37, 43, STONE_L, 50), (35, 51, PUR_L, 70),
              (33, 53, STONE_D, 90)]
    frags1 = [(12, 42, PUR_L, 90), (10, 44, STONE_L, 70),
              (13, 48, STONE_L, 110), (36, 42, STONE_L, 60),
              (37, 43, PUR_L, 70), (35, 51, STONE_D, 90),
              (33, 53, PUR_L, 80)]
    for x, yy, c, a in (frags0 if phase == 0 else frags1):
        f.p(x, y(yy), c, a)

    return f.im


def frame_bbox(im: Image.Image):
    return im.getbbox()


def main() -> None:
    DOC.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    # 4-frame idle: subtle 1px breath + alternating edge fragments.
    frames = [draw_figure(0, 0), draw_figure(-1, 0), draw_figure(0, 1), draw_figure(-1, 1)]
    sheet = Image.new("RGBA", (W * 4, H), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.alpha_composite(fr, (i * W, 0))

    sheet_path = OUT / "guide_echo_idle_4f.png"
    sheet.save(sheet_path, format="PNG", optimize=False)

    # Single preview: native 1x + 3x NEAREST in one file.
    font_path = ENGINE / "assets" / "fonts" / "tutorial_zh.ttf"
    font = ImageFont.truetype(str(font_path), 12) if font_path.exists() else ImageFont.load_default()
    # 1x 48x64 at (10,10); 3x 144x192 at (82,10)
    pv = Image.new("RGBA", (240, 224), (18, 30, 34, 255))
    base = frames[0]
    pv.alpha_composite(base, (10, 10))
    pv.alpha_composite(base.resize((W * 3, H * 3), Image.NEAREST), (82, 10))
    d = ImageDraw.Draw(pv)
    # thin keylines around both
    d.rectangle((9, 9, 58, 74), outline=(72, 92, 96, 255), width=1)
    d.rectangle((81, 9, 225, 201), outline=(72, 92, 96, 255), width=1)
    d.text((10, 202), "1x native", font=font, fill=(214, 208, 195, 255))
    d.text((82, 202), "3x NEAREST", font=font, fill=(214, 208, 195, 255))
    preview_path = DOC / "guide_echo_preview.png"
    pv.save(preview_path, format="PNG", optimize=False)

    # manifest
    frame_info = []
    for i, fr in enumerate(frames):
        bb = frame_bbox(fr)
        frame_info.append({
            "frame": i,
            "rect_in_sheet": [i * W, 0, W, H],
            "bbox": list(bb) if bb else None,
            "foot_anchor": list(ANCHOR),
        })

    manifest = {
        "asset": "guide_echo_idle_4f",
        "display_name": "守望者残响",
        "usage": "第一关两处固定显现的同一个守望者残响待机帧；开发只用 48x64 帧显示，不依赖 Godot 自绘身体；第二关石碑保留",
        "sheet": {
            "path": "assets/guide_echo_20261112/guide_echo_idle_4f.png",
            "size": [W * 4, H],
            "frame_size": [W, H],
            "frame_count": 4,
            "layout": "横排 4 帧，每帧 48x64；帧序 0..3",
            "sha256": hashlib.sha256(sheet_path.read_bytes()).hexdigest().upper(),
        },
        "generator": "自制素材/守望者残响_20261112/generate_guardian_echo.py",
        "readme": "自制素材/守望者残响_20261112/README_权属说明.md",
        "anchor": {
            "foot": [24, 60],
            "note": "脚底锚；可见残影最低约 y57，保留 3px 微悬空",
        },
        "visible_bbox": frame_info[0]["bbox"],
        "bounds_note": "4 帧主可见轮廓在 x10..38 / y13..57 内；每帧 bbox 见 frames；头顶气口和脚下约 3px 微悬空保留",
        "frames": frame_info,
        "palette": {
            "outline": "#3E3847",
            "deep": "#4A4555",
            "purple_dark": "#5C5568",
            "purple": "#706780",
            "purple_light": "#8A7E99",
            "stone_dark": "#7F7A80",
            "stone": "#A8A3A5",
            "stone_light": "#C6C1BE",
            "stone_high": "#E0DCD5",
            "face_dark": "#6B5A55",
            "face": "#C9A98F",
            "face_light": "#E6C7A9",
            "eye": "#2E2833",
            "warm_glow": "#F0D7B4",
        },
        "animation": {
            "type": "idle only",
            "breath": "frame 1/3 整体上移 1px；不是整体透明闪烁",
            "fragments": "frame 2/3 交替少量边缘残片 alpha/位置；面部与主体保持清楚",
            "not_included": ["walk", "combat", "portrait", "large illustration", "voice", "pathfinding"],
        },
        "source": {
            "created_for": "星核旅人 / 古代守望者的残响",
            "method": "本地 Pillow 逐像素绘制 + AI 辅助排布/调色；不是人类手绘",
            "third_party": "角色像素图未使用第三方图像或生成服务；审查预览标签仅使用项目已有 Fusion Pixel 字体（OFL-1.1），不进入角色帧表；未下载、未购买、未上传",
            "license_note": "为本项目新绘制的本地派生素材；不得冒充第三方作者或许可，也不得声称人类手绘；最终视觉待协调者验收",
        },
        "preview": {
            "path": "自制素材/守望者残响_20261112/guide_echo_preview.png",
            "content": "同一原生单帧的 1x 与 3x NEAREST 对照；不是引擎截图",
        },
        "verification": {
            "self_checked": True,
            "not_verified": [
                "Godot import/Nearest 游戏内实际显示",
                "与主角并肩/两处显现点/相机夹屏的实际观感",
                "第一关两处残响的 scene 接入与第二关石碑保留（开发后续）",
                "协调者最终视觉验收",
            ],
        },
    }
    manifest_path = OUT / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    print("sheet", sheet_path, sheet.size, "frames", len(frames))
    for i, info in enumerate(frame_info):
        print(i, info["bbox"])
    print("preview", preview_path, pv.size)


if __name__ == "__main__":
    main()
