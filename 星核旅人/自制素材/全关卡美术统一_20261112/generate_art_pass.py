# -*- coding: utf-8 -*-
"""
《星核旅人》全关卡美术统一 pass（2026-11-12）
仅生成新的派生 PNG 与一份 1:1 对照图；不覆盖任何源稿、runtime PNG、scene 或 script。

输入（只读）：
  基础场景原型/assets/map/ruin_platform_tiles.png
  基础场景原型/assets/level02_platform_v3/layer_platform_visual_640.png
  基础场景原型/assets/level02_platform_v3/layer_platform_decor_640.png

输出：
  基础场景原型/assets/art_pass_20261112/
    ruin_platform_tiles_warmgrey.png
    level02_platform_visual_highstep_trim_640.png
    level02_platform_decor_seams_640.png
    manifest.json
  自制素材/全关卡美术统一_20261112/
    原生对照_BEFORE_AFTER.png
    保护报告.md

运行：D:\\minic\\envs\\2024212971\\python.exe generate_art_pass.py
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]          # 星核旅人
ENGINE = ROOT / "基础场景原型"
DOC = ROOT / "自制素材" / "全关卡美术统一_20261112"
OUT = ENGINE / "assets" / "art_pass_20261112"

SRC_ATLAS = ENGINE / "assets" / "map" / "ruin_platform_tiles.png"
SRC_VISUAL = ENGINE / "assets" / "level02_platform_v3" / "layer_platform_visual_640.png"
SRC_DECOR = ENGINE / "assets" / "level02_platform_v3" / "layer_platform_decor_640.png"
SCENE_L1 = ENGINE / "scenes" / "level_01.tscn"
SCENE_L2 = ENGINE / "scenes" / "level_02.tscn"

EXPECTED = {
    SRC_ATLAS: "3A9FC34281FE33B17194C706B666BD8E0A9B4F0B697DC426481EF7199EF8B5B2",
    SRC_VISUAL: "EE8D38E32684BD1170563C2784FA3E241D64818D2F1DFA7DF0F922677CB04290",
    SRC_DECOR: "58C58508ABD051ED79F52C2EC53401B1BD8B243156050B17C97F529FC0A82A9F",
}

# 8 个源颜色的精确索引映射。仅改 RGB，alpha 原样保留。
# 石材 6 级取自已批准桥身/石柱的暖灰阶；最深一级加一档更暗的暖炭，保留缝隙深度。
PALETTE = {
    (15, 13, 14): (48, 42, 49),     # #0F0D0E -> #302A31
    (32, 26, 35): (66, 55, 62),     # #201A23 -> #42373E
    (70, 52, 52): (89, 74, 81),     # #463434 -> #594A51
    (109, 81, 78): (113, 96, 100),  # #6D514E -> #716064
    (165, 129, 127): (143, 128, 126),  # #A5817F -> #8F807E
    (206, 178, 175): (190, 180, 168),  # #CEB2AF -> #BEB4A8
    (28, 46, 17): (61, 79, 64),     # 苔藓暗 -> #3D4F40（与桥身 decor 的苔藓同族）
    (38, 93, 34): (105, 126, 107),  # 苔藓亮 -> #697E6B
}
STONE = set(PALETTE.values())

HORIZONTAL_STEP = (152, 274, 208, 288)  # 世界坐标，右下开区间；真实碰撞厚 14px
SEAM_CENTERS = (260, 284, 324, 348, 372)
SEAM_GAPS = ((256, 264), (280, 288), (320, 328), (344, 352), (368, 376))


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def assert_source_hashes() -> dict[str, str]:
    hashes = {}
    for path, expected in EXPECTED.items():
        assert path.exists(), f"missing source: {path}"
        got = sha256(path)
        assert got == expected, f"source hash mismatch: {path}\n got {got}\n exp {expected}"
        hashes[path.name] = got
    return hashes


def save_rgba(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=False)


def diff_bbox(a: Image.Image, b: Image.Image) -> tuple[int, int, int, int] | None:
    """Return half-open bbox of differing pixels (including alpha differences)."""
    assert a.size == b.size
    pa, pb = a.load(), b.load()
    w, h = a.size
    xs: list[int] = []
    ys: list[int] = []
    for y in range(h):
        for x in range(w):
            if pa[x, y] != pb[x, y]:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), min(ys), max(xs) + 1, max(ys) + 1)


def make_ground_atlas() -> tuple[Image.Image, dict]:
    src = Image.open(SRC_ATLAS).convert("RGBA")
    assert src.size == (192, 32), f"unexpected atlas size {src.size}"
    assert src.width % 16 == 0 and src.height % 16 == 0

    out = src.copy()
    sp, op = src.load(), out.load()
    unknown = set()
    changed = 0
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = sp[x, y]
            if a == 0:
                # 保留透明像素的原始 RGBA 字节，避免无意义的隐藏色变化。
                op[x, y] = (r, g, b, a)
                continue
            if (r, g, b) not in PALETTE:
                unknown.add((r, g, b))
                continue
            nr, ng, nb = PALETTE[(r, g, b)]
            if (nr, ng, nb) != (r, g, b):
                changed += 1
            op[x, y] = (nr, ng, nb, a)
    assert not unknown, f"unmapped colors: {unknown}"
    assert out.size == src.size
    assert out.tobytes() != src.tobytes()
    # alpha 必须逐字节不变
    assert list(out.getchannel("A").tobytes()) == list(src.getchannel("A").tobytes())
    # 16x16 网格边界必须仍可整除
    assert out.width % 16 == 0 and out.height % 16 == 0

    counts = {}
    for n, (r, g, b, _a) in src.getcolors(maxcolors=1 << 20):
        counts[f"#{r:02X}{g:02X}{b:02X}"] = counts.get(f"#{r:02X}{g:02X}{b:02X}", 0) + n
    out_counts = {}
    for n, (r, g, b, _a) in out.getcolors(maxcolors=1 << 20):
        out_counts[f"#{r:02X}{g:02X}{b:02X}"] = out_counts.get(f"#{r:02X}{g:02X}{b:02X}", 0) + n

    info = {
        "size": list(out.size),
        "grid": "12 columns x 2 rows of 16x16 tiles",
        "alpha_preserved": True,
        "changed_rgb_pixels": changed,
        "source_color_counts": counts,
        "derived_color_counts": out_counts,
        "mapping": [
            {"from": "#%02X%02X%02X" % k, "to": "#%02X%02X%02X" % v}
            for k, v in PALETTE.items()
        ],
    }
    return out, info


def make_highstep_visual() -> tuple[Image.Image, dict]:
    src = Image.open(SRC_VISUAL).convert("RGBA")
    assert src.size == (640, 360), f"unexpected visual size {src.size}"
    out = src.copy()
    op = out.load()
    x0, y0, x1, y1 = HORIZONTAL_STEP

    # 14px 真实厚度：y274..287。在底端 3px 内做完整下沿，y>=288 清空。
    for y in range(285, 288):
        for x in range(x0, x1):
            if y == 285 and x == 180:
                # 保留原中央石缝，让它落进下沿，不像被整条盖掉。
                op[x, y] = (89, 74, 81, 255)
            elif y == 285:
                op[x, y] = (122, 104, 107, 255)  # #7A686B，浅一档的底沿倒角
            else:
                op[x, y] = (89, 74, 81, 255)     # #594A51，与右侧短台底边同色
    for y in range(288, 300):
        for x in range(x0, x1):
            op[x, y] = (0, 0, 0, 0)

    # 下沿必须完整：56 列在 y287 全不透明，y288..299 全透明。
    for x in range(x0, x1):
        assert op[x, 287][3] == 255
        for y in range(288, 300):
            assert op[x, y][3] == 0
    # 只允许高台区域变化
    bbox = diff_bbox(src, out)
    assert bbox is not None and bbox[0] >= x0 and bbox[1] >= 285 and bbox[2] <= x1 and bbox[3] <= 300, bbox

    info = {
        "source_rect": [152, 274, 56, 26],
        "visible_footprint_after": [152, 274, 56, 14],
        "collision_rect": [152, 274, 56, 14],
        "collision_bottom_y": 288,
        "visible_bottom_y": 287,
        "clear_alpha_from_y": 288,
        "diff_bbox": list(bbox),
    }
    return out, info


def make_decor_with_seams() -> tuple[Image.Image, dict]:
    src = Image.open(SRC_DECOR).convert("RGBA")
    assert src.size == (640, 360), f"unexpected decor size {src.size}"
    out = src.copy()
    op = out.load()

    # 1) 去掉高台下沿以下的两颗旧苔藓像素（它们会悬在新下沿之外）。
    for x in (160, 161):
        assert op[x, 289][3] > 0
        op[x, 289] = (0, 0, 0, 0)

    # 2) 去掉旧 1px 半透明刻痕，重画为 3px 宽的石色短槽 + 浅边。
    for c in SEAM_CENTERS:
        for y in range(267, 273):
            assert op[c, y] == (66, 55, 62, 72), (c, y, op[c, y])
            op[c, y] = (0, 0, 0, 0)
        # 左肩：极轻的暗边
        for y in range(268, 273):
            op[c - 1, y] = (89, 74, 81, 150)
        # 中央刻槽：从顶缘下方开始，落到压顶下沿
        for y in range(266, 274):
            op[c, y] = (66, 55, 62, 205)
        # 右侧 1px 浅色凿边
        for y in range(267, 272):
            op[c + 1, y] = (190, 180, 168, 120)

    # 物理缝仍是 8px，未封口：记录实际缝中心而非扩大缺口。
    info = {
        "physical_gaps": [list(g) for g in SEAM_GAPS],
        "mark_centers": list(SEAM_CENTERS),
        "mark_style": {
            "left_shoulder": "#594A51 alpha150, y268..272",
            "center_groove": "#42373E alpha205, y266..273",
            "right_chisel": "#BEB4A8 alpha120, y267..271",
        },
        "mark_bboxes": [
            [c - 1, 266, c + 2, 274] for c in SEAM_CENTERS
        ],
        "highstep_removed_pixels": [[160, 289], [161, 289]],
    }
    bbox = diff_bbox(src, out)
    assert bbox is not None
    info["diff_bbox"] = list(bbox)
    # 只允许 5 个缝的 3px 标记与高台下方 2 个像素变化；桥面主轮廓不动。
    allowed = set()
    for c in SEAM_CENTERS:
        for x in range(c - 1, c + 2):
            for y in range(266, 274):
                allowed.add((x, y))
        for y in range(267, 273):
            allowed.add((c, y))
    allowed.update({(160, 289), (161, 289)})
    sp = src.load()
    for y in range(src.height):
        for x in range(src.width):
            if sp[x, y] != op[x, y]:
                assert (x, y) in allowed, f"unexpected decor change at {(x, y)}"
    return out, info


def tile_ground(atlas: Image.Image, width: int, height: int) -> Image.Image:
    """Replicate Level02Block/LevelTerrainBlock drawing at native 16px tiles."""
    assert width % 16 == 0
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    cols = width // 16
    rows = (height + 15) // 16
    for row in range(rows):
        tile_h = min(16, height - row * 16)
        if tile_h <= 0:
            continue
        for col in range(cols):
            if row == 0:
                atlas_col = 0 if col == 0 else (11 if col == cols - 1 else 1 + ((col - 1) % 10))
                atlas_row = 0
            else:
                atlas_col = 0 if col == 0 else (11 if col == cols - 1 else 1 + ((col + row * 3) % 10))
                atlas_row = 1
            region = atlas.crop((atlas_col * 16, atlas_row * 16, atlas_col * 16 + 16, atlas_row * 16 + tile_h))
            out.alpha_composite(region, (col * 16, row * 16))
    return out


def make_comparison(before_atlas: Image.Image, after_atlas: Image.Image,
                    before_visual: Image.Image, after_visual: Image.Image,
                    before_decor: Image.Image, after_decor: Image.Image) -> None:
    panel_w, panel_h, header_h = 640, 360, 32
    crop_y = 224
    view_h = panel_h - crop_y
    canvas = Image.new("RGBA", (panel_w * 2, view_h + header_h), (13, 22, 25, 255))
    draw = ImageDraw.Draw(canvas)

    font_path = ENGINE / "assets" / "fonts" / "tutorial_zh.ttf"
    font = ImageFont.truetype(str(font_path), 12) if font_path.exists() else ImageFont.load_default()
    draw.text((12, 9), "修改前 · 源资产 1:1 局部（示意合成）", font=font, fill=(232, 226, 211, 255))
    draw.text((panel_w + 12, 9), "修改后 · 派生资产 1:1（示意合成，非引擎截图）", font=font, fill=(232, 226, 211, 255))
    draw.line((panel_w, 0, panel_w, view_h + header_h), fill=(52, 70, 73, 255), width=1)

    def panel(atlas: Image.Image, visual: Image.Image, decor: Image.Image) -> Image.Image:
        img = Image.new("RGBA", (panel_w, panel_h), (109, 154, 161, 255))
        img.alpha_composite(tile_ground(atlas, panel_w, 40), (0, 320))
        img.alpha_composite(visual, (0, 0))
        img.alpha_composite(decor, (0, 0))
        return img.crop((0, crop_y, panel_w, panel_h))

    canvas.alpha_composite(panel(before_atlas, before_visual, before_decor), (0, header_h))
    canvas.alpha_composite(panel(after_atlas, after_visual, after_decor), (panel_w, header_h))
    save_rgba(canvas, DOC / "原生对照_BEFORE_AFTER.png")


def write_manifest(hashes: dict[str, str], atlas_info: dict, step_info: dict,
                   seam_info: dict, outputs: dict[str, str]) -> None:
    manifest = {
        "pass": "全关卡美术统一_20261112",
        "scope": "仅派生 PNG；未改 scene/script/collision；未覆盖源稿或旧 runtime PNG",
        "sources": {
            "atlas": {
                "path": "assets/map/ruin_platform_tiles.png",
                "sha256": hashes[SRC_ATLAS.name],
                "credit": "Szadi art. / Pixel Platformer World；原图 main_lev_buildA.png 区域 x224..415, y80..111；来源与许可见 ASSET_CREDITS.md；本轮未重新核实许可",
            },
            "visual": {
                "path": "assets/level02_platform_v3/layer_platform_visual_640.png",
                "sha256": hashes[SRC_VISUAL.name],
                "credit": "项目内已批准 V3 平台视觉层；上游生成脚本见 自制素材/第二关平台完整造型预览_V3；本轮未重新核实上游素材许可",
            },
            "decor": {
                "path": "assets/level02_platform_v3/layer_platform_decor_640.png",
                "sha256": hashes[SRC_DECOR.name],
                "credit": "项目内已批准 V3 平台 decor 层；本轮只增刻槽/去高台下方苔藓",
            },
        },
        "derived": {
            "atlas": {
                "path": "assets/art_pass_20261112/ruin_platform_tiles_warmgrey.png",
                "sha256": outputs["atlas"],
                "size": atlas_info["size"],
                "grid": atlas_info["grid"],
                "alpha_preserved": atlas_info["alpha_preserved"],
                "diff": "全部不透明像素按 8 色索引映射；alpha、尺寸、12x2 个 16px 格、表层/底层结构不变",
                **atlas_info,
            },
            "visual": {
                "path": "assets/art_pass_20261112/level02_platform_visual_highstep_trim_640.png",
                "sha256": outputs["visual"],
                "size": [640, 360],
                **step_info,
            },
            "decor": {
                "path": "assets/art_pass_20261112/level02_platform_decor_seams_640.png",
                "sha256": outputs["decor"],
                "size": [640, 360],
                **seam_info,
            },
        },
        "replacement": {
            "ground_all_levels": {
                "source": "assets/map/ruin_platform_tiles.png",
                "derived": "assets/art_pass_20261112/ruin_platform_tiles_warmgrey.png",
                "note": "同尺寸 192x32；建议开发备份后替换 runtime 文件，保持 Nearest 与 .import 不变，所有使用该 atlas 的两关/旧沙盒同步生效",
            },
            "level02_visual": {
                "source": "assets/level02_platform_v3/layer_platform_visual_640.png",
                "derived": "assets/art_pass_20261112/level02_platform_visual_highstep_trim_640.png",
                "note": "同尺寸 640x360；替换后 5 个 AtlasTexture 切片坐标不变；只改左高台 y285..299",
            },
            "level02_decor": {
                "source": "assets/level02_platform_v3/layer_platform_decor_640.png",
                "derived": "assets/art_pass_20261112/level02_platform_decor_seams_640.png",
                "note": "同尺寸 640x360；只改 5 个缝中心与左高台 y289 两个苔藓像素",
            },
        },
        "not_verified": [
            "Godot 实际 import/渲染与 Nearest 过滤",
            "游戏内碰撞、脚感、施力站位与人工观感",
            "原始素材许可是否允许再分发/改色（本轮未重新核实）",
            "第一关引导者 NPC 身份与形象（未制作）",
        ],
    }
    dest = OUT / "manifest.json"
    dest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    DOC.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    before_hashes = assert_source_hashes()
    scene_hashes_before = {p.name: sha256(p) for p in (SCENE_L1, SCENE_L2)}

    atlas, atlas_info = make_ground_atlas()
    visual, step_info = make_highstep_visual()
    decor, seam_info = make_decor_with_seams()

    out_atlas = OUT / "ruin_platform_tiles_warmgrey.png"
    out_visual = OUT / "level02_platform_visual_highstep_trim_640.png"
    out_decor = OUT / "level02_platform_decor_seams_640.png"
    save_rgba(atlas, out_atlas)
    save_rgba(visual, out_visual)
    save_rgba(decor, out_decor)

    outputs = {
        "atlas": sha256(out_atlas),
        "visual": sha256(out_visual),
        "decor": sha256(out_decor),
    }

    # 重新读取磁盘文件，防止编码/保存环节改变了像素。
    disk_atlas = Image.open(out_atlas).convert("RGBA")
    disk_visual = Image.open(out_visual).convert("RGBA")
    disk_decor = Image.open(out_decor).convert("RGBA")
    assert disk_atlas.size == (192, 32)
    assert disk_visual.size == (640, 360)
    assert disk_decor.size == (640, 360)
    assert list(disk_atlas.getchannel("A").tobytes()) == list(Image.open(SRC_ATLAS).getchannel("A").tobytes())

    after_hashes = {p.name: sha256(p) for p in (SRC_ATLAS, SRC_VISUAL, SRC_DECOR)}
    assert after_hashes == before_hashes, "source changed during generation"
    scene_hashes_after = {p.name: sha256(p) for p in (SCENE_L1, SCENE_L2)}
    assert scene_hashes_after == scene_hashes_before, "scene changed during generation"

    make_comparison(
        Image.open(SRC_ATLAS).convert("RGBA"), atlas,
        Image.open(SRC_VISUAL).convert("RGBA"), visual,
        Image.open(SRC_DECOR).convert("RGBA"), decor,
    )

    write_manifest(before_hashes, atlas_info, step_info, seam_info, outputs)

    report = f"""# 保护报告：全关卡美术统一 pass（2026-11-12）

## 1. 源文件哈希（生成前后一致）
- `assets/map/ruin_platform_tiles.png`: `{before_hashes[SRC_ATLAS.name]}`
- `assets/level02_platform_v3/layer_platform_visual_640.png`: `{before_hashes[SRC_VISUAL.name]}`
- `assets/level02_platform_v3/layer_platform_decor_640.png`: `{before_hashes[SRC_DECOR.name]}`
- `scenes/level_01.tscn`: `{scene_hashes_before['level_01.tscn']}`
- `scenes/level_02.tscn`: `{scene_hashes_before['level_02.tscn']}`

生成前后上述哈希均一致；本轮没有写入 scene/script/docs/progress/ASSET_CREDITS，也没有覆盖上述源稿或旧 runtime PNG。

## 2. 派生文件
- `assets/art_pass_20261112/ruin_platform_tiles_warmgrey.png`：`{outputs['atlas']}`
- `assets/art_pass_20261112/level02_platform_visual_highstep_trim_640.png`：`{outputs['visual']}`
- `assets/art_pass_20261112/level02_platform_decor_seams_640.png`：`{outputs['decor']}`
- `assets/art_pass_20261112/manifest.json`：接入路径、来源、差异边界与未验项

## 3. 结构检查
- ground：源/派生均为 192x32、RGBA；alpha 通道逐字节一致；12x2 个 16x16 格结构不变；不透明像素全部落在 8 色映射内；1 个透明像素保留原字节。
- highstep visual：仅 `{step_info['diff_bbox']}` 变化；y287 整行 56px 不透明，y288..299 全透明；可见厚度 14px，与碰撞底 y288 一致；主桥/右短台像素未变。
- decor：仅 5 个缝中心 3px 标记与高台 y289 两个苔藓像素变化；diff bbox `{seam_info['diff_bbox']}`；未新增金/青色；实际 8px 物理缝未扩、未封。
- 5 个标记中心：{', '.join(str(c) for c in SEAM_CENTERS)}；每处 bbox 宽度 3px，小于真实缝宽 8px。

## 4. 未验证
- Godot 编辑器/运行时实际 import、Nearest 过滤与最终画面。
- 游戏内碰撞、角色从高台下走过、桥面施力站位、AI/运输/完成流程。
- 原始素材许可是否允许改色与再分发；本轮只保留来源记录，未重新核实。
- 第一关引导者 NPC 的身份、形象、站位与替换方案（未制作，待用户确认）。

## 5. 保护边界
- 未改 `scenes/`、`scripts/`、`docs/`、`progress.md`、`ASSET_CREDITS.md`。
- 未改主角/守卫源图、DS03 背景、checkpoint/exit、rune_stone、star_core、石柱装饰。
- 未运行引擎，因此本报告只证明像素/文件级生成结果，不证明游戏实景验收。
"""
    (DOC / "保护报告.md").write_text(report, encoding="utf-8")
    print("generated:")
    for p in (out_atlas, out_visual, out_decor, DOC / "原生对照_BEFORE_AFTER.png", DOC / "保护报告.md"):
        print(" ", p, p.stat().st_size)


if __name__ == "__main__":
    main()
