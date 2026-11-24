#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""DS03：从已暂采用的 V2 静态图重新拆出可动建筑层 + 干净底图。

只读输入：
  后景遗迹细化预览_V2/background_detail_v2_640x360.png   （已暂采用的画面）
  云海遗迹背景概念示意/background_only_v7.png            （V2 的来源，用于取 V2 的 818px 差异）
  云海遗迹背景概念示意/generate_background_v6.py         （只执行其中的纯几何定义）
  云海遗迹背景动态重制_DS02/config.json + layers/*.png    （只读，用于参考叠图/遮挡检查）

输出全部在本目录：
  art_assets/  建筑层、底图、可选静态残石
  art_checks/  隔离、参考叠图、遮挡、极值、alpha/mask、V2 可见差异
  art_manifest.json / ART_README.md

不修改 DS02、V2、V7、Godot；不写原图；不联网。
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFont
from scipy import ndimage

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent
PROJECT = ASSETS.parent
V2DIR = ASSETS / "后景遗迹细化预览_V2"
CONCEPT = ASSETS / "云海遗迹背景概念示意"
DS02 = ASSETS / "云海遗迹背景动态重制_DS02"
ASSET_DIR = HERE / "art_assets"
CHECK_DIR = HERE / "art_checks"
BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\background-ds03-baseline-a410495bf65545a093322abb90b2645c\hashes.json"
)

W, H = 640, 360
CLOUD = {
    (133, 173, 181), (148, 186, 191), (142, 181, 187), (151, 189, 193),
    (164, 198, 201), (157, 192, 197), (135, 174, 182), (148, 184, 190),
}
# V6 原始色（只用于构造/还原，不作为交付色）
STONE = (67, 94, 116)
SHADE = (48, 74, 97)
LIGHT = (101, 128, 145)
MID = (82, 110, 132)
JOINT = (55, 82, 104)
EDGE = (112, 139, 153)
# V7 的桥体调色映射，逐字复刻其规则（hidden face 也保持同一套石质语言）
PALETTE = {
    STONE: (94, 122, 138), SHADE: (82, 110, 128), LIGHT: (113, 139, 151),
    MID: (101, 128, 143), JOINT: (91, 119, 135), EDGE: (118, 144, 154),
}
FOG_STONE = (116, 148, 160)      # 桥脚/院落补面的空气色（不是云色）
G4_PLINTH = (58, 86, 108)        # 院落足部补面的接触暗色
GAP = (474, 483, 184, 189)       # x0,x1,y0,y1（V2 的 5px 空气：9 列 × 5 行）
NUB = (472, 484, 170, 184)       # 被右残柱柱头盖住的岛底片段，归 G5
DEBRIS_BOXES = [                 # DS02 四组游离浮石（本轮不进底图，由工程复用）
    (303, 207, 342, 249),
    (264, 243, 300, 265),
    (379, 235, 388, 246),
    (231, 289, 262, 322),
]
ARCH_BOXES = [(268, 230, 342, 320), (386, 265, 442, 315)]
FAR_RUIN_BOX = (560, 210, 594, 248)


def sky(y: int) -> tuple[int, int, int]:
    return tuple(round(a + (b - a) * min(1, y / 315))
                 for a, b in zip((45, 90, 112), (120, 165, 174)))


def mix(a, b, t: float):
    return tuple(round(x * (1 - t) + z * t) for x, z in zip(a, b))


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().lower()


def load_baseline() -> list[dict]:
    data = json.loads(BASELINE.read_text(encoding="utf-8-sig"))
    rows = []
    for e in data:
        p = Path(e["path"])
        if not p.is_absolute():
            p = PROJECT / p
        rows.append({"path": str(p), "sha256": e["sha256"].lower()})
    return rows


def load_inputs():
    v2 = np.array(Image.open(V2DIR / "background_detail_v2_640x360.png").convert("RGB"))
    assert v2.shape == (H, W, 3)
    v7_img = Image.open(CONCEPT / "background_only_v7.png").convert("RGB")
    assert v7_img.size == (1280, 720)
    v7 = np.array(v7_img.resize((W, H), Image.Resampling.NEAREST))
    assert np.array_equal(np.array(v7_img), np.repeat(np.repeat(v7, 2, 0), 2, 1))
    return v2.astype(np.int16), v7.astype(np.int16)


def load_v6_geometry():
    src = (CONCEPT / "generate_background_v6.py").read_text(encoding="utf-8")
    geo = src[src.index("layer=Image.new('RGBA'"):src.index("im.paste(layer,")]
    ns = dict(Image=Image, ImageDraw=ImageDraw, ImageChops=ImageChops,
              math=math, STONE=STONE, SHADE=SHADE, LIGHT=LIGHT, MID=MID, JOINT=JOINT, EDGE=EDGE)
    exec(compile(geo, "v6_geometry_only", "exec"), ns)
    layer = ns["layer"]
    lay = np.array(layer)
    return {
        "layer": layer,
        "rgba": lay,
        "alpha": lay[..., 3] == 255,
        "solid": np.array(ns["solid"]) > 0,
        "left": np.array(ns["left"]) > 0,
        "right": np.array(ns["right"]) > 0,
    }


def v7_bridge_rgb(geo) -> np.ndarray:
    """把 V7 对桥体的逐像素处理应用到整块 V6 桥体（含被云/石遮住的隐藏面）。"""
    out = np.zeros((H, W, 3), np.int16)
    for y in range(H):
        for x in range(W):
            if not geo["alpha"][y, x]:
                continue
            c = tuple(int(v) for v in geo["rgba"][y, x, :3])
            stone = PALETTE[c]
            if y < 205:
                stone = mix(c, stone, .78)
            if c == JOINT and (y >= 220 or (x // 18) % 3 != 0):
                stone = (95, 123, 139)
            wave = (0, 2, 3, 1, -1, -2, -1, 1)[(x // 24) % 8]
            depth = y + wave
            fog = 0.0
            for start, amount in [(231, .08), (239, .18), (247, .31), (254, .46),
                                  (260, .62), (266, .77), (272, .90), (279, 1.0)]:
                if depth >= start:
                    fog = amount
            out[y, x] = mix(stone, (133, 173, 181), fog)
    return out


def first_cloud_y(v2, x: int, y0: int = 200) -> int | None:
    for y in range(y0, H):
        if tuple(int(v) for v in v2[y, x]) in CLOUD:
            return y
    return None


def build(v2, v7, geo):
    """返回各层 RGBA + 掩膜信息。坐标均为全画布。"""
    sky_arr = np.zeros((H, W, 3), np.int16)
    for y in range(H):
        sky_arr[y, :, :] = sky(y)

    cloud = np.zeros((H, W), bool)
    content = np.zeros((H, W), bool)
    for y in range(H):
        for x in range(W):
            c = tuple(int(v) for v in v2[y, x])
            if c in CLOUD:
                cloud[y, x] = True
            elif y >= 130 and c != sky(y):
                content[y, x] = True

    bridge_any = geo["alpha"].copy()
    # V2 的 5px 空气：从右桥柱头切掉；该柱头以上的岛底片段归 G5
    gap = np.zeros((H, W), bool)
    gap[GAP[2]:GAP[3], GAP[0]:GAP[1]] = True
    nub = np.zeros((H, W), bool)
    for y in range(NUB[2], NUB[3]):
        for x in range(NUB[0], NUB[1]):
            c = tuple(int(v) for v in v2[y, x])
            if c != sky(y) and c not in CLOUD:
                nub[y, x] = True
    assert not (gap & nub).any()

    # ---- G1/G2：同一套 V6 几何，按 x 分左右；缺口/岛底片段不在桥图层 ----
    left_px = geo["alpha"] & (np.arange(W)[None, :] <= 320)
    right_px = geo["alpha"] & (np.arange(W)[None, :] >= 400)
    assert not (left_px & right_px).any()
    yy = np.arange(H)[:, None]
    # V6 原 solid 几何到 y=299(end 300)。交付层保留到 y=299：
    # y≤282 是可见/潜在可见面；y283–299 是浮动 reserve（sea_main 顶边 260–282，
    # 任何相位都被不透明云海覆盖，但桥体上浮 1.5px 时必须有实体接住云顶边缘）。
    g1 = left_px & (yy <= 299)
    g2 = right_px & ~gap & ~nub & (yy <= 299)

    debris = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in DEBRIS_BOXES:
        debris[y0:y1, x0:x1] = True
    # 四组浮石的精确像素（不是外接框），用于建筑层避让/背后补面
    debris_px = np.zeros((H, W), bool)
    for nm, dx, dy in (("debris_central", 303, 207), ("debris_cluster", 264, 243),
                       ("debris_tiny", 379, 235), ("debris_low", 231, 289)):
        a = np.array(Image.open(DS02 / "layers" / f"{nm}.png").convert("RGBA"))[..., 3] > 0
        debris_px[dy:dy + a.shape[0], dx:dx + a.shape[1]] |= a

    remap = v7_bridge_rgb(geo)
    rgb1 = remap.copy()
    rgb2 = remap.copy()
    ext1 = np.zeros((H, W), bool)
    ext2 = np.zeros((H, W), bool)
    boundary = {}

    for mask, rgb, ext in ((g1, rgb1, ext1), (g2, rgb2, ext2)):
        for x in range(W):
            if not mask[:, x].any():
                continue
            yc = first_cloud_y(v2, x)
            if yc is None:
                continue
            b = yc - 1
            boundary[x] = b
            if b >= 299:
                continue
            ys = np.where(mask[:, x])[0]
            above = [y for y in ys if y <= b]
            if not above:
                continue
            base_col = np.median(v2[max(0, b - 3):b + 1, x], axis=0).round().astype(int)
            base_col = tuple(int(v) for v in base_col)
            for y in range(b + 1, 300):
                if not mask[y, x]:
                    continue
                t = min(0.62, 0.08 + 0.52 * (y - b) / max(1, 282 - b))
                c = mix(base_col, FOG_STONE, t)
                if c in CLOUD:
                    c = (c[0], c[1], min(255, c[2] + 1))
                rgb[y, x] = c
                ext[y, x] = True

        # 原 V2 可见像素逐像素照搬；被云/石遮住的像素用同一套 V7 石质语言补面
        vis = mask & content & ~debris
        for y in range(H):
            for x in range(W):
                if vis[y, x]:
                    rgb[y, x] = v2[y, x]
        # V2 的 818px 局部修改（断口/接触影）全部落在可见范围，照搬
        delta = np.any(v2 != v7, axis=2) & mask
        for y in range(H):
            for x in range(W):
                if delta[y, x]:
                    rgb[y, x] = v2[y, x]

    # ---- G3/G4/G5：V2 远建筑；G4 补桥面后的足部，G5 补回岛底被柱头盖住的片段 ----
    def far_mask(box):
        x0, y0, x1, y1 = box
        m = np.zeros((H, W), bool)
        for y in range(y0, y1):
            for x in range(x0, x1):
                if content[y, x] and not bridge_any[y, x] and not debris_px[y, x]:
                    m[y, x] = True
        return m

    g3 = far_mask((28, 160, 112, 204))
    g4 = far_mask((232, 160, 322, 220))
    g5 = far_mask((436, 138, 540, 204)) | nub
    # 底图远残迹不归建筑组
    far_b = np.zeros((H, W), bool)
    far_b[FAR_RUIN_BOX[1]:FAR_RUIN_BOX[3], FAR_RUIN_BOX[0]:FAR_RUIN_BOX[2]] = True
    for m in (g3, g4, g5):
        m &= ~far_b

    rgb3 = np.where(g3[..., None], v2, 0).astype(np.int16)
    rgb5 = np.where(g5[..., None], v2, 0).astype(np.int16)
    rgb4 = np.where(g4[..., None], v2, 0).astype(np.int16)

    # G4 的隐藏足部：只在“被桥面顶边正好裁掉”的列向下补 4px；桥面移动时不会露洞
    ext4 = np.zeros((H, W), bool)
    for x in range(W):
        ys = np.where(g4[:, x])[0]
        if not len(ys):
            continue
        bottom = int(ys.max())
        deck = np.where(geo["solid"][:, x])[0]
        if not len(deck):
            continue
        deck_top = int(deck.min())
        # 只补“主桥面顶边 y205 直接压住”的列；断口凹槽里可见的足部不补，
        # 避免在断口里新增可见基座。主桥面下沉时，这 1px 天空线由接触影接管。
        if deck_top != 205 or bottom >= 205:
            continue
        base_col = np.median(v2[max(0, bottom - 3):bottom + 1, x], axis=0).round().astype(int)
        base_col = tuple(int(v) for v in base_col)
        for y in range(bottom + 1, 210):
            if g4[y, x]:
                continue
            g4[y, x] = True
            ext4[y, x] = True
            if y < deck_top:
                rgb4[y, x] = mix(base_col, (38, 64, 84), 0.38)
            else:
                rgb4[y, x] = mix(base_col, G4_PLINTH, 0.18)

    # G4 台基右端被 debris_central 遮住的片段：只补岩石实际盖住的像素，
    # 用同一行左邻台基色；静止时完全在岩石后，浮石上移时才露出。
    dc_mask = debris_px.copy()
    for y in range(206, 219):
        sx = 302
        if not g4[y, sx]:
            continue
        col = tuple(int(v) for v in rgb4[y, sx])
        for x in range(303, 310):
            if g4[y, x] or not dc_mask[y, x]:
                continue
            g4[y, x] = True
            ext4[y, x] = True
            rgb4[y, x] = col

    # ---- 云中残拱：纯石质静态层（放主云海之后、近云海之前） ----
    arch = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in ARCH_BOXES:
        for y in range(y0, y1):
            for x in range(x0, x1):
                if content[y, x] and not bridge_any[y, x] and not g3[y, x] \
                        and not g4[y, x] and not g5[y, x] and not debris[y, x] \
                        and not far_b[y, x]:
                    arch[y, x] = True
    rgb_arch = np.where(arch[..., None], v2, 0).astype(np.int16)

    # ---- 静态残石：不属于四组动体、也不属于建筑/残拱的 V2 石屑 ----
    assigned = bridge_any | g3 | g4 | g5 | arch | far_b | debris
    static = content & ~assigned
    # 只保留连通块 >= 3px，去掉 V2 云的 1px 毛刺
    lab, n = ndimage.label(static, np.ones((3, 3)))
    keep = np.zeros((H, W), bool)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None:
            continue
        if int((lab[sl] == i).sum()) >= 3:
            keep |= lab == i
    static = keep
    rgb_static = np.where(static[..., None], v2, 0).astype(np.int16)

    # ---- 干净底图：天空梯度 + 极远静态残迹（右后方的极淡塔状残迹） ----
    base = sky_arr.copy()
    far = far_b & content
    base[far] = v2[far]

    layers = {
        "base_sky": (base.astype(np.uint8), np.ones((H, W), bool), None),
        "G1_left_bridge": (rgb1.astype(np.uint8), g1, None),
        "G2_right_bridge": (rgb2.astype(np.uint8), g2, None),
        "G3_left_hall_island": (rgb3.astype(np.uint8), g3, None),
        "G4_far_courtyard": (rgb4.astype(np.uint8), g4, None),
        "G5_right_temple_island": (rgb5.astype(np.uint8), g5, None),
        "arch_stone": (rgb_arch.astype(np.uint8), arch, None),
        "rock_remnants_static": (rgb_static.astype(np.uint8), static, None),
    }
    info = {
        "cloud": cloud, "content": content, "gap": gap, "nub": nub,
        "debris": debris, "debris_px": debris_px, "far": far, "static": static, "arch": arch,
        "ext1": ext1, "ext2": ext2, "ext4": ext4, "boundary": boundary,
        "g1": g1, "g2": g2,
        "vis1": g1 & content & ~debris_px, "vis2": g2 & content & ~debris_px,
        "vis3": g3, "vis4": g4 & ~ext4, "vis5": g5,
        "delta": delta,
    }
    return layers, info


def to_rgba(rgb: np.ndarray, mask: np.ndarray) -> Image.Image:
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = np.where(mask[..., None], rgb, 0)
    out[..., 3] = np.where(mask, 255, 0)
    return Image.fromarray(out)


def crop_layer(rgba: Image.Image, mask: np.ndarray):
    x0, y0, x1, y1 = Image.fromarray((mask * 255).astype(np.uint8)).getbbox()
    return rgba.crop((x0, y0, x1, y1)), [x0, y0], [x1 - x0, y1 - y0]


def alpha_over(dst: np.ndarray, src: np.ndarray, x: int, y: int) -> None:
    h, w = src.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww = min(w - sx0, W - dx0)
    hh = min(h - sy0, H - dy0)
    if ww <= 0 or hh <= 0:
        return
    s = src[sy0:sy0 + hh, sx0:sx0 + ww]
    d = dst[dy0:dy0 + hh, dx0:dx0 + ww].astype(np.float32)
    a = s[..., 3:4].astype(np.float32) / 255.0
    dst[dy0:dy0 + hh, dx0:dx0 + ww] = np.clip(
        np.rint(s[..., :3].astype(np.float32) * a + d * (1 - a)), 0, 255).astype(np.uint8)


def font(size=12, bold=False):
    try:
        name = "consolab.ttf" if bold else "consola.ttf"
        return ImageFont.truetype(f"C:/Windows/Fonts/{name}", size)
    except Exception:
        return ImageFont.load_default()


def banner(draw, xy, text, fill=(255, 255, 255)):
    draw.text(xy, text, font=font(12), fill=fill)


def load_ds02():
    cfg = json.loads((DS02 / "config.json").read_text(encoding="utf-8"))
    layers = {}
    for s in cfg["sky"]:
        layers[s["name"]] = np.array(Image.open(DS02 / s["file"]).convert("RGBA"))
    for s in cfg["sea"]:
        layers[s["name"]] = np.array(Image.open(DS02 / s["file"]).convert("RGBA"))
    for s in cfg["debris"]:
        layers[s["name"]] = np.array(Image.open(DS02 / s["file"]).convert("RGBA"))
    arch = np.array(Image.open(DS02 / cfg["arch_overlay"]).convert("RGBA"))
    island = np.array(Image.open(DS02 / cfg["island_overlay"]).convert("RGBA"))
    return cfg, layers, arch, island


def sea_canvas(tile: np.ndarray, phase: int, period: int) -> np.ndarray:
    out = np.zeros((H, W, 4), np.uint8)
    for ox in (phase - period, phase):
        sx0, dx0 = max(0, -int(ox)), max(0, int(ox))
        ww = min(period - sx0, W - dx0)
        if ww > 0:
            out[:, dx0:dx0 + ww] = tile[:, sx0:sx0 + ww]
    return out


def compose(v2, info, my_layers, ds02, t=0.0, with_debris=True, with_static=True,
            my_offsets=None, base_override=None):
    cfg, L, _, _ = ds02
    my_offsets = my_offsets or {}
    if base_override is not None:
        c = np.array(base_override).astype(np.uint8)
    else:
        c = np.array(Image.open(ASSET_DIR / "base_sky_640x360.png").convert("RGB"))
    for s in cfg["sky"]:
        sp = L[s["name"]]
        x = s["x0"] + s["speed"] * t
        cycle = W + s["size"][0] + s["wrap_gap"]
        while x > W + 8:
            x -= cycle
        alpha_over(c, sp, int(round(x)), s["y0"])
    # 远建筑（G3/G4/G5）在桥之前
    for name in ("G3_left_hall_island", "G4_far_courtyard", "G5_right_temple_island",
                 "G1_left_bridge", "G2_right_bridge"):
        sp = np.array(Image.open(ASSET_DIR / f"{name.lower()}.png").convert("RGBA"))
        dx, dy = my_offsets.get(name, (0, 0))
        alpha_over(c, sp, dx, dy)
    # 主云海（同一张层覆盖两桥）
    main = next(s for s in cfg["sea"] if s["name"] == "sea_main")
    near = next(s for s in cfg["sea"] if s["name"] == "sea_near")
    pm = int(round((main["speed"] * t) % main["period"])) % main["period"]
    pn = int(round((near["speed"] * t) % near["period"])) % near["period"]
    alpha_over(c, sea_canvas(L["sea_main"], pm, main["period"]), 0, 0)
    # 静态残拱（纯石质）
    sp = np.array(Image.open(ASSET_DIR / "arch_stone.png").convert("RGBA"))
    dx, dy = my_offsets.get("arch_stone", (0, 0))
    alpha_over(c, sp, dx, dy)
    alpha_over(c, sea_canvas(L["sea_near"], pn, near["period"]), 0, 0)
    if with_static:
        sp = np.array(Image.open(ASSET_DIR / "rock_remnants_static.png").convert("RGBA"))
        dx, dy = my_offsets.get("rock_remnants_static", (0, 0))
        alpha_over(c, sp, dx, dy)
    if with_debris:
        for d in cfg["debris"]:
            bob = d["amp_y"] * math.sin(2 * math.pi * t / d["period"] + d["phase"])
            alpha_over(c, L[d["name"]], int(d["x0"]), int(round(d["y0"] + bob)))
    return c


def main():
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    CHECK_DIR.mkdir(parents=True, exist_ok=True)
    for p in CHECK_DIR.glob("*.png"):
        p.unlink()
    prot_before = load_baseline()

    v2, v7 = load_inputs()
    geo = load_v6_geometry()
    layers, info = build(v2, v7, geo)

    ds02 = load_ds02()
    cfg, L, ds02_arch, ds02_island = ds02

    specs = {
        "base_sky": dict(group="BG_STATIC", depth=0, order=0, float=False,
                         file="art_assets/base_sky_640x360.png",
                         note="天空梯度 + 右后方极远静态塔状残迹（x560-594,y210-248）；无云、无桥、无浮石"),
        "G1_left_bridge": dict(group="G1", depth=30, order=0, float=True, amp=1.5,
                               file="art_assets/g1_left_bridge.png",
                               note="左断桥整体：桥面/横梁/柱/拱/墩，刚性同动；y283–299 为浮动 reserve"),
        "G2_right_bridge": dict(group="G2", depth=30, order=1, float=True, amp=1.0,
                                file="art_assets/g2_right_bridge.png",
                                note="右断桥整体：与左桥同深度、同时绘制；柱头 y189 保留；y283–299 为浮动 reserve"),
        "G3_left_hall_island": dict(group="G3", depth=20, order=0, float=True, amp=0.8,
                                    file="art_assets/g3_left_hall_island.png",
                                    note="左端残厅浮岛整体"),
        "G4_far_courtyard": dict(group="G4", depth=20, order=1, float=True, amp=0.6,
                                 file="art_assets/g4_far_courtyard.png",
                                 note="左后远院落整体；足部在桥面后有 4px 隐藏补面"),
        "G5_right_temple_island": dict(group="G5", depth=20, order=2, float=True, amp=1.5,
                                       file="art_assets/g5_right_temple_island.png",
                                       note="右侧小祠浮岛整体（含岩底与 V2 柱头覆盖片段）；与 G2 的相对极值受限"),
        "arch_stone": dict(group="STATIC", depth=45, order=0, float=False,
                           file="art_assets/arch_stone.png",
                           note="中部/下部残拱纯石质层；主云海之后、近云海之前"),
        "rock_remnants_static": dict(group="STATIC", depth=60, order=0, float=False,
                                     file="art_assets/rock_remnants_static.png",
                                     note="不属于四组动体的静态石屑（上断块/远岩/云中小石）；可选"),
    }

    manifest_layers = []
    for name, (rgb, mask, _) in layers.items():
        rgba = to_rgba(rgb, mask)
        img, off, size = crop_layer(rgba, mask)
        dest = ASSET_DIR / Path(specs[name]["file"]).name
        img.save(dest)
        # 用回读图重算 alpha，确保交付文件真实
        back = np.array(Image.open(dest).convert("RGBA"))
        assert back.shape[1] == size[0] and back.shape[0] == size[1]
        assert np.array_equal(back[..., 3] == 255, mask[off[1]:off[1] + size[1], off[0]:off[0] + size[0]])
        alpha_vals = sorted(set(np.unique(back[..., 3]).tolist()))
        vis = info.get(f"vis{name[1]}") if name.startswith("G") and name[1].isdigit() else None
        v2_visible = int(vis.sum()) if vis is not None else int(mask.sum())
        if name == "base_sky":
            v2_visible = int(info["far"].sum())
        rebuilt = int(mask.sum()) - v2_visible if vis is not None else 0
        rebuilt_visible = int((info["ext4"] & ~info["g1"] & ~info["debris_px"]).sum()) \
            if name == "G4_far_courtyard" else 0
        manifest_layers.append({
            "id": name,
            "group": specs[name]["group"],
            "file": specs[name]["file"],
            "abs_path": str(dest),
            "sha256": sha(dest),
            "size": size,
            "offset": off,
            "depth": specs[name]["depth"],
            "order": specs[name]["order"],
            "float_allowed": specs[name]["float"],
            "float_amp_max_px": specs[name].get("amp", 0.0),
            "rigid": True,
            "alpha": {
                "mode": "binary 0/255（无半透明、无羽化）" if name != "base_sky" else "不透明底图",
                "unique_values": alpha_vals,
                "note": specs[name]["note"],
            },
            "pixels": {
                "v2_visible": v2_visible,
                "rebuilt_hidden": rebuilt - rebuilt_visible,
                "rebuilt_visible_contact": rebuilt_visible,
            },
        })

    # 每层的像素口径补充（按组统计补面/转移，而不是逐层硬凑）
    layer_offsets = {l["id"]: l["offset"] for l in manifest_layers}
    g1_vis = int(info["vis1"].sum()); g2_vis = int(info["vis2"].sum())
    ext1 = int(info["ext1"].sum()); ext2 = int(info["ext2"].sum())
    yy_rows = np.arange(H)[:, None]
    ext1_res = int((info["ext1"] & (yy_rows >= 283)).sum())
    ext2_res = int((info["ext2"] & (yy_rows >= 283)).sum())
    g1_res = int((info["g1"] & (yy_rows >= 283)).sum())
    g2_res = int((info["g2"] & (yy_rows >= 283)).sum())
    g4_vis = int(info["vis4"].sum()); ext4 = int(info["ext4"].sum())
    ext4_vis = int((info["ext4"] & ~info["g1"] & ~info["debris_px"]).sum())
    ext4_hidden = ext4 - ext4_vis
    nub_px = int((info["nub"] & info["content"]).sum())
    nub_transfer = int((info["nub"] & geo["alpha"]).sum())
    gap_px = int(info["gap"].sum())
    gap_hidden = int((info["gap"] & geo["alpha"]).sum())

    # ---------------- 检查图 ----------------
    # 0) 干净底图：只应看到天空梯度 + 右后方极远静态残迹
    base_img = Image.open(ASSET_DIR / "base_sky_640x360.png").convert("RGB")
    bi = base_img.resize((W * 2, H * 2), Image.Resampling.NEAREST)
    bd = ImageDraw.Draw(bi)
    bd.rectangle([0, 0, bi.width - 1, 20], fill=(12, 18, 22))
    banner(bd, (4, 4), f"CLEAN BASE: sky gradient + far ruin only ({int(info['far'].sum())} px)")
    bi.save(CHECK_DIR / "00_base_clean_2x.png")

    # 1) 纯建筑隔离：全部组叠在洋红上，任何残云/云色块都会很显眼
    iso = np.zeros((H, W, 3), np.uint8)
    iso[:] = (255, 0, 255)
    for name in ("G3_left_hall_island", "G4_far_courtyard", "G5_right_temple_island",
                 "G1_left_bridge", "G2_right_bridge", "arch_stone", "rock_remnants_static"):
        im = np.array(Image.open(ASSET_DIR / Path(specs[name]["file"]).name).convert("RGBA"))
        off = next(l["offset"] for l in manifest_layers if l["id"] == name)
        alpha_over(iso, im, off[0], off[1])
    Image.fromarray(iso).resize((W * 2, H * 2), Image.Resampling.NEAREST).save(
        CHECK_DIR / "01_buildings_on_magenta_2x.png")

    # 2) 每组 3x 隔离（贴洋红，带 bbox/offset）
    for name in ("G1_left_bridge", "G2_right_bridge", "G3_left_hall_island",
                 "G4_far_courtyard", "G5_right_temple_island"):
        p = np.array(Image.open(ASSET_DIR / Path(specs[name]["file"]).name).convert("RGBA"))
        off = next(l["offset"] for l in manifest_layers if l["id"] == name)
        pad = 6
        cell = np.zeros((p.shape[0] + pad * 2, p.shape[1] + pad * 2, 3), np.uint8)
        cell[:] = (255, 0, 255)
        alpha_over(cell, p, pad, pad)
        im = Image.fromarray(cell).resize((cell.shape[1] * 3, cell.shape[0] * 3),
                                          Image.Resampling.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, im.width - 1, 18], fill=(15, 18, 20))
        banner(d, (4, 3), f"{name}  offset={tuple(off)}  size={p.shape[1]}x{p.shape[0]}")
        im.save(CHECK_DIR / f"02_{name}_3x.png")

    # 3) 参考叠图：V2 建筑 + DS02 静态天空云/云海/浮石，t=0；不是动态完成声明
    ref = compose(v2, info, layers, ds02, 0.0, my_offsets=layer_offsets)
    Image.fromarray(ref).save(CHECK_DIR / "03_reference_overlay_640.png")
    Image.fromarray(ref).resize((W * 2, H * 2), Image.Resampling.NEAREST).save(
        CHECK_DIR / "03_reference_overlay_2x.png")
    # 与 V2 的差异（诚实报告：云海是 DS02 重制的，不是建筑层的差）
    diff = np.abs(ref.astype(np.int16) - v2.astype(np.int16))
    dm = np.any(diff != 0, axis=2)
    above = dm.copy(); above[250:] = False
    dm_vis = np.zeros((H, W, 3), np.uint8)
    dm_vis[..., 0] = np.clip(diff.max(axis=2) * 10, 0, 255)
    Image.fromarray(dm_vis).save(CHECK_DIR / "04_reference_vs_v2_diff.png")

    # 5) 同一层主云海覆盖两桥：固定 phase=0，左右脚同一帧
    crop_l = (25, 195, 210, 300)
    crop_r = (455, 195, 580, 300)
    sc = 3
    cells = []
    for box, title in ((crop_l, "LEFT FOOT  same sea_main"), (crop_r, "RIGHT FOOT  same sea_main")):
        im = Image.fromarray(ref).crop(box)
        im = im.resize((im.width * sc, im.height * sc), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, im.width - 1, 20], fill=(12, 18, 22))
        banner(d, (4, 4), f"{title}  phase_main=0  t=0")
        cells.append(im)
    pad = 10
    out = Image.new("RGB", (sum(c.width for c in cells) + pad * 3, cells[0].height + pad * 2),
                    (18, 24, 28))
    x = pad
    for c in cells:
        out.paste(c, (x, pad)); x += c.width + pad
    out.save(CHECK_DIR / "05_occlusion_both_bridges_same_layer_3x.png")

    # 6) 右桥脚：DS02 旧图 vs 新图（根因 before/after）
    ds02_ref = Image.open(DS02 / "reference.png").convert("RGB")
    after = Image.fromarray(ref)
    box = (455, 190, 585, 305)
    before = ds02_ref.crop(box).resize(((box[2] - box[0]) * 4, (box[3] - box[1]) * 4),
                                       Image.Resampling.NEAREST)
    aft = after.crop(box).resize(((box[2] - box[0]) * 4, (box[3] - box[1]) * 4),
                                 Image.Resampling.NEAREST)
    out = Image.new("RGB", (before.width * 2 + 30, before.height + 24), (18, 24, 28))
    d = ImageDraw.Draw(out)
    banner(d, (6, 5), "BEFORE: DS02 island_overlay after sea (static white cloud)")
    banner(d, (before.width + 18, 5), "AFTER: both bridges before sea (no static cloud)")
    out.paste(before, (0, 24)); out.paste(aft, (before.width + 24, 24))
    out.save(CHECK_DIR / "06_right_foot_before_after_4x.png")

    # 7) 右岛/断柱安全极值：静态、最差整数位移（G5 +2 / G2 -1）
    sky_ref = np.zeros((H, W, 3), np.uint8)
    for y in range(H):
        sky_ref[y, :, :] = sky(y)
    g2img = np.array(Image.open(ASSET_DIR / "g2_right_bridge.png").convert("RGBA"))
    g5img = np.array(Image.open(ASSET_DIR / "g5_right_temple_island.png").convert("RGBA"))
    off2 = next(l["offset"] for l in manifest_layers if l["id"] == "G2_right_bridge")
    off5 = next(l["offset"] for l in manifest_layers if l["id"] == "G5_right_temple_island")
    panels = []
    for g5dy, g2dy, tag in ((0, 0, "rest: 5px air"), (2, -1, "worst: 2px air (G5+2 / G2-1)"),
                            (-2, 1, "other extreme: 8px air")):
        c = sky_ref.copy()
        alpha_over(c, g5img, off5[0], off5[1] + g5dy)
        alpha_over(c, g2img, off2[0], off2[1] + g2dy)
        box = (465, 168, 500, 205)
        im = Image.fromarray(c).crop(box)
        im = im.resize((im.width * 10, im.height * 10), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, im.width - 1, 20], fill=(12, 18, 22))
        banner(d, (4, 4), tag)
        panels.append(im)
    out = Image.new("RGB", (sum(p.width for p in panels) + 24, panels[0].height + 24), (18, 24, 28))
    x = 6
    for p in panels:
        out.paste(p, (x, 24)); x += p.width + 6
    out.save(CHECK_DIR / "07_right_island_column_extremes_10x.png")

    # 8) 左后院落/左桥极值：G4 -1 / G1 +2（相对 3px，4px 补面仍覆盖）
    g1img = np.array(Image.open(ASSET_DIR / "g1_left_bridge.png").convert("RGBA"))
    g4img = np.array(Image.open(ASSET_DIR / "g4_far_courtyard.png").convert("RGBA"))
    off1 = next(l["offset"] for l in manifest_layers if l["id"] == "G1_left_bridge")
    off4 = next(l["offset"] for l in manifest_layers if l["id"] == "G4_far_courtyard")
    panels = []
    for g4dy, g1dy, tag in ((0, 0, "rest: G4 foot sits on y205 deck edge"),
                            (-1, 2, "relative 3px: contact still closed")):
        c = sky_ref.copy()
        alpha_over(c, g4img, off4[0], off4[1] + g4dy)
        alpha_over(c, g1img, off1[0], off1[1] + g1dy)
        box = (238, 194, 300, 222)
        im = Image.fromarray(c).crop(box)
        im = im.resize((im.width * 12, im.height * 12), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, im.width - 1, 20], fill=(12, 18, 22))
        banner(d, (4, 4), tag)
        gy = (205 - box[1]) * 12
        d.line([(0, gy), (im.width, gy)], fill=(255, 90, 90), width=1)
        panels.append(im)
    out = Image.new("RGB", (sum(p.width for p in panels) + 18, panels[0].height + 24), (18, 24, 28))
    x = 6
    for p in panels:
        out.paste(p, (x, 24)); x += p.width + 6
    out.save(CHECK_DIR / "08_far_courtyard_bridge_extreme_12x.png")

    # 9) alpha/mask 检查：白=255，黑=0；没有灰阶
    rows = []
    for name, (rgb, mask, _) in layers.items():
        if name == "base_sky":
            continue
        m = np.zeros((H, W, 3), np.uint8)
        m[mask] = (255, 255, 255)
        im = Image.fromarray(m)
        cell = Image.new("RGB", (W + 8, H + 26), (18, 24, 28))
        cell.paste(im, (4, 22))
        ImageDraw.Draw(cell).text((6, 5), f"{name}  alpha0/255  px={int(mask.sum())}",
                                  font=font(11), fill=(220, 230, 234))
        rows.append(cell)
    cols = 2
    cw = W + 8; ch = H + 26
    sheet = Image.new("RGB", (cw * cols + 8, ch * ((len(rows) + cols - 1) // cols) + 8), (12, 16, 18))
    for i, r in enumerate(rows):
        sheet.paste(r, (4 + (i % cols) * (cw + 4), 4 + (i // cols) * ch))
    sheet.save(CHECK_DIR / "09_alpha_masks.png")

    # 10) V2 可见像素差异：预期=0 个“未解释”差异；G4 的 1px 接触影单独标成琥珀色
    vis_any = np.zeros((H, W), bool)
    unexpected = np.zeros((H, W), bool)
    contact_px = np.zeros((H, W), bool)
    for name in ("G1_left_bridge", "G2_right_bridge", "G3_left_hall_island",
                 "G4_far_courtyard", "G5_right_temple_island"):
        im = np.array(Image.open(ASSET_DIR / Path(specs[name]["file"]).name).convert("RGBA"))
        off = next(l["offset"] for l in manifest_layers if l["id"] == name)
        rgb = np.zeros((H, W, 3), np.uint8)
        a = im[..., 3] == 255
        rgb[off[1]:off[1] + im.shape[0], off[0]:off[0] + im.shape[1]][a] = \
            im[..., :3][a]
        mask = np.zeros((H, W), bool)
        mask[off[1]:off[1] + im.shape[0], off[0]:off[0] + im.shape[1]] = a
        front = (info["g1"] | info["debris_px"]) if name == "G4_far_courtyard" \
            else np.zeros((H, W), bool)
        visible = mask & ~front
        vis_any |= visible & info["content"]
        diff = visible & info["content"] & np.any(rgb != v2.astype(np.uint8), axis=2)
        if name == "G4_far_courtyard":
            contact = (info["ext4"] & ~front) & np.any(rgb != v2.astype(np.uint8), axis=2)
            contact_px |= contact
            diff &= ~contact
        unexpected |= diff
    has_mm = int(unexpected.sum())
    intentional_contact = int(contact_px.sum())
    base_img = (v2.astype(np.int16) * 0.55 + 25).astype(np.uint8)
    base_img[contact_px] = (255, 190, 60)
    base_img[unexpected] = (255, 32, 32)
    Image.fromarray(base_img).resize((W * 2, H * 2), Image.Resampling.NEAREST).save(
        CHECK_DIR / "10_v2_visible_pixel_diff_2x.png")

    # 11) 右桥脚三帧：证明脚下云在动、没有静态白云残留
    panels = []
    for t in (0.0, 4.0, 8.0):
        f = compose(v2, info, layers, ds02, t, my_offsets=layer_offsets)
        im = Image.fromarray(f).crop((455, 190, 585, 305))
        im = im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, im.width - 1, 20], fill=(12, 18, 22))
        banner(d, (4, 4), f"right foot  t={t:.0f}s  sea_main phase={int(round((4.2*t)%1278))%1278}")
        panels.append(im)
    out = Image.new("RGB", (sum(p.width for p in panels) + 24, panels[0].height + 24), (18, 24, 28))
    x = 6
    for p in panels:
        out.paste(p, (x, 24)); x += p.width + 6
    out.save(CHECK_DIR / "11_right_foot_cloud_motion_3phase_4x.png")

    # 12) 桥脚云顶最低相位：验证补面与云顶之间不出现天空缝
    main_spec = next(s for s in cfg["sea"] if s["name"] == "sea_main")
    top_list = [int(v) for v in main_spec["top"]]
    P = int(main_spec["period"])

    def phase_for_top(x: int, ytop: int) -> int:
        for idx, v in enumerate(top_list):
            if v == ytop:
                return (x - idx) % P
        return 0

    panels = []
    for foot_x, label in ((49, "left pier x49"), (476, "right pier x476")):
        ph = phase_for_top(foot_x, 282)
        tt = ph / main_spec["speed"]
        f = compose(v2, info, layers, ds02, tt, my_offsets=layer_offsets)
        box = (foot_x - 22, 252, foot_x + 22, 300)
        im = Image.fromarray(f).crop(box)
        im = im.resize((im.width * 10, im.height * 10), Image.Resampling.NEAREST)
        d = ImageDraw.Draw(im)
        d.rectangle([0, 0, im.width - 1, 20], fill=(12, 18, 22))
        banner(d, (4, 4), f"{label}: sea_main top=282 static dy=0; float proof in 13")
        gy = (282 - box[1]) * 10
        d.line([(0, gy), (im.width, gy)], fill=(255, 90, 90), width=1)
        panels.append(im)
    out = Image.new("RGB", (sum(p.width for p in panels) + 24, panels[0].height + 24), (18, 24, 28))
    x = 6
    for p in panels:
        out.paste(p, (x, 24)); x += p.width + 6
    out.save(CHECK_DIR / "12_pier_cloud_lowest_phase_10x.png")

    # 13) 浮动 reserve 联合极值：sea_main 云顶最低 282 + 两桥最大上浮
    #     旧版把桥层裁到 y=282(end 283)：G1 上浮 1.5px 后底边 281.5，比最低云顶 282 高，
    #     会露 0.5 逻辑像素天空（整数取整 -2 时露 1px）。本轮按 V6 原 solid 几何保留到
    #     y=299(end 300)，用交付 PNG 的 alpha + sea_main 实际 mask 数值验证，不靠肉眼。
    reserve_rows = np.arange(H)[:, None] >= 283
    main_t0 = sea_canvas(L["sea_main"], 0, P)
    reserve_px = (info["g1"] | info["g2"]) & reserve_rows
    reserve_uncovered = int((reserve_px & ~(main_t0[..., 3] > 0)).sum())
    assert reserve_uncovered == 0, reserve_uncovered

    joint = {}
    panels = []
    for foot_x, name, dy_int in ((49, "G1_left_bridge", -2), (476, "G2_right_bridge", -1)):
        ph = phase_for_top(foot_x, 282)
        tt = ph / main_spec["speed"]
        pm2 = int(round((main_spec["speed"] * tt) % P)) % P
        cmain = sea_canvas(L["sea_main"], pm2, P)
        calpha = cmain[..., 3] > 0
        first_c = np.full(W, 999, int)
        for x in range(W):
            ys = np.where(calpha[:, x])[0]
            if len(ys):
                first_c[x] = int(ys.min())

        im = np.array(Image.open(ASSET_DIR / Path(specs[name]["file"]).name).convert("RGBA"))
        off = next(l["offset"] for l in manifest_layers if l["id"] == name)
        a = im[..., 3] == 255
        m = np.zeros((H, W), bool)
        m[off[1] + dy_int:off[1] + dy_int + a.shape[0], off[0]:off[0] + a.shape[1]] = a
        pier_cols = [int(x) for x in np.where(a[-1])[0] + off[0]]
        bottom_end = int(off[1] + dy_int + a.shape[0])
        margins = [bottom_end - first_c[x] for x in pier_cols]
        min_margin = min(margins)
        assert min_margin >= 1, (name, min_margin)
        # 可见石面到前云之间必须整列都有桥体实体（mask 直接验证，不靠颜色）
        missing_px = 0
        for x in pier_cols:
            for y in range(260, min(first_c[x], bottom_end)):
                if not m[y, x]:
                    missing_px += 1
        assert missing_px == 0, (name, missing_px)

        offs2 = dict(layer_offsets)
        offs2[name] = (off[0], off[1] + dy_int)
        f = compose(v2, info, layers, ds02, tt, my_offsets=offs2)
        sky_px = 0
        for x in pier_cols:
            for y in range(260, min(first_c[x], bottom_end)):
                if tuple(int(v) for v in f[y, x]) == sky(y):
                    sky_px += 1
        assert sky_px == 0, (name, sky_px)
        joint[name] = {
            "foot_x": foot_x,
            "sea_main_phase": pm2,
            "cloud_top_at_foot": int(first_c[foot_x]),
            "bridge_up_int_px": int(-dy_int),
            "bridge_bottom_end_y": bottom_end,
            "previous_cut_end_y": 283,
            "previous_bottom_end_y": 283 + dy_int,
            "previous_exposure_px_at_foot": max(0, int(first_c[foot_x]) - (283 + dy_int)),
            "pier_columns": len(pier_cols),
            "min_bridge_to_cloud_overlap_px": int(min_margin),
            "missing_mask_px": missing_px,
            "composite_sky_px": sky_px,
        }

        box = (foot_x - 26, 258, foot_x + 26, 304)
        im2 = Image.fromarray(f).crop(box)
        im2 = im2.resize((im2.width * 10, im2.height * 10), Image.Resampling.NEAREST)
        arr = np.array(im2)
        mc = m[box[1]:box[3], box[0]:box[2]]
        edge = mc & ~ndimage.binary_erosion(mc, np.ones((3, 3)))
        for ey, ex in zip(*np.where(edge)):
            arr[ey * 10:(ey + 1) * 10, ex * 10] = (70, 255, 130)
        im2 = Image.fromarray(arr)
        d = ImageDraw.Draw(im2)
        d.rectangle([0, 0, im2.width - 1, 20], fill=(12, 18, 22))
        banner(d, (4, 4), f"{name}: sea_top=282  dy={dy_int}  end={bottom_end}  "
                          f"overlap={min_margin}px")
        for yy_line, col, label in ((first_c[foot_x], (255, 70, 70), "cloud"),
                                    (283, (255, 176, 60), "old end"),
                                    (bottom_end, (90, 220, 255), "new end")):
            gy = (yy_line - box[1]) * 10
            d.line([(0, gy), (im2.width, gy)], fill=col, width=1)
            d.text((4, gy + 1), label, font=font(10), fill=col)
        banner(d, (4, im2.height - 13), "green = bridge alpha edge; sky px in stone->cloud = 0",
               fill=(190, 255, 210))
        panels.append(im2)
    out = Image.new("RGB", (sum(p.width for p in panels) + 24, panels[0].height + 24), (18, 24, 28))
    x = 6
    for p in panels:
        out.paste(p, (x, 24)); x += p.width + 6
    out.save(CHECK_DIR / "13_pier_float_reserve_joint_extreme_10x.png")


    # ---------------- 数值自审 ----------------
    # 纯建筑层不得含云色（残拱允许少量雾色重合，单独报告）
    cloud_rgb_in_groups = {}
    for name in ("G1_left_bridge", "G2_right_bridge", "G3_left_hall_island",
                 "G4_far_courtyard", "G5_right_temple_island"):
        im = np.array(Image.open(ASSET_DIR / Path(specs[name]["file"]).name).convert("RGBA"))
        a = im[..., 3] == 255
        px = im[..., :3][a]
        cloud_rgb_in_groups[name] = {
            "colors": sum(1 for c in {tuple(int(v) for v in row) for row in px} if c in CLOUD),
            "pixels": sum(1 for row in px if tuple(int(v) for v in row) in CLOUD),
        }
    arch_img = np.array(Image.open(ASSET_DIR / "arch_stone.png").convert("RGBA"))
    arch_cloud_colors = sum(1 for row in arch_img[..., :3][arch_img[..., 3] == 255]
                            if tuple(int(v) for v in row) in CLOUD)

    # G5/G2 空气：静态与整数极值
    def min_air(g5dy, g2dy):
        m5 = np.zeros((H, W), bool); m2 = np.zeros((H, W), bool)
        a5 = g5img[..., 3] == 255; a2 = g2img[..., 3] == 255
        m5[off5[1]+g5dy:off5[1]+g5dy+a5.shape[0], off5[0]:off5[0]+a5.shape[1]] = a5
        m2[off2[1]+g2dy:off2[1]+g2dy+a2.shape[0], off2[0]:off2[0]+a2.shape[1]] = a2
        # 只在断柱顶所在的 x 带上量竖向空气
        gap_cols = range(GAP[0], GAP[1])
        best = 99
        for x in gap_cols:
            y5 = np.where(m5[:, x])[0]
            y2 = np.where(m2[:, x])[0]
            if len(y5) and len(y2):
                best = min(best, int(y2.min() - y5.max() - 1))
        # 2D 最近距离（8 邻接）
        dist = ndimage.distance_transform_edt(~m2)
        near5 = dist[m5]
        cheb = int(np.floor(near5.min())) if len(near5) else 99
        return best, cheb

    air_rest = min_air(0, 0)
    air_worst = min_air(2, -1)

    # 参考叠图 vs V2 的差异口径
    dm_total = int(dm.sum())
    dm_above = int(above.sum())
    right_foot_static_diff = int(dm[205:283, 455:560].sum())
    ys, xs = np.where(dm)
    diff_bbox = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None

    # 基线核对
    prot_after = load_baseline()
    prot_rows = []
    ok = True
    for a, b in zip(prot_before, prot_after):
        same = a["sha256"] == b["sha256"] == sha(Path(b["path"])) if Path(b["path"]).is_file() else False
        ok &= same
        if not same:
            prot_rows.append({"path": b["path"], "baseline": a["sha256"], "now": b["sha256"]})
    assert ok, prot_rows

    manifest = {
        "name": "云海遗迹背景动态修复_DS03",
        "status": "art layers + clean plate; motion/render/test to be implemented by engineering",
        "revision": "DS03.1（2026-11-03）：G1/G2 按 V6 原 solid 几何把隐藏石面保留到 y=299（end 300），y283–299 作为浮动 reserve；新增 13 联合极值检查。",
        "date": "2026-11-03",
        "canvas": [W, H],
        "render_scale": 2,
        "coordinate_space": "logical 640x360; offsets are top-left in this space; PNGs are tight crops",
        "approved_source": {
            "file": str(V2DIR / "background_detail_v2_640x360.png"),
            "sha256": sha(V2DIR / "background_detail_v2_640x360.png"),
            "note": "用户已暂认可 V2（“先这样吧”），本轮以其为建筑外观真值",
        },
        "groups": {
            "G1": {"name": "左断桥整体", "members": ["桥面", "横梁", "柱", "拱", "桥墩", "基础"],
                   "rigid": True, "float_allowed": True, "amp_max_px": 1.5,
                   "period_s_suggested": 9.5, "phase_suggested": 0.0},
            "G2": {"name": "右断桥整体", "members": ["桥面", "横梁", "残柱", "拱", "桥墩", "基础"],
                   "rigid": True, "float_allowed": True, "amp_max_px": 1.0,
                   "period_s_suggested": 10.5, "phase_suggested": 0.35},
            "G3": {"name": "左端残厅浮岛", "members": ["残厅", "柱", "岛台", "岩底"],
                   "rigid": True, "float_allowed": True, "amp_max_px": 0.8,
                   "period_s_suggested": 11.0, "phase_suggested": 1.2},
            "G4": {"name": "左后远院落", "members": ["塔身", "拱门", "残墙", "足部补面"],
                   "rigid": True, "float_allowed": True, "amp_max_px": 0.6,
                   "period_s_suggested": 12.0, "phase_suggested": 2.0},
            "G5": {"name": "右侧小祠浮岛", "members": ["小祠", "平台", "岩底", "V2 柱头覆盖片段"],
                   "rigid": True, "float_allowed": True, "amp_max_px": 1.5,
                   "period_s_suggested": 8.5, "phase_suggested": 0.0},
        },
        "layers": manifest_layers,
        "stack": {
            "rule": "G1/G2 必须在 sea_main 之前绘制，两桥同深度；不允许把右桥下部/柱脚单独提到云海之后重盖",
            "order": [
                {"depth": 0, "content": ["base_sky"]},
                {"depth": 10, "content": ["DS02 sky_bank_* / sky_*_wisp"]},
                {"depth": 20, "content": ["G3", "G4", "G5"]},
                {"depth": 30, "content": ["G1", "G2"]},
                {"depth": 40, "content": ["DS02 sea_main + its shadows (clipped)"]},
                {"depth": 45, "content": ["arch_stone"]},
                {"depth": 50, "content": ["DS02 sea_near + shadow_low"]},
                {"depth": 60, "content": ["rock_remnants_static"]},
                {"depth": 70, "content": ["DS02 debris_central/cluster/tiny/low"]},
            ],
        },
        "reuse_from_ds02": {
            "sky": ["sky_bank_left", "sky_bank_right", "sky_mid_wisp", "sky_low_wisp_r",
                    "sky_left_wisp", "sky_low_wisp_l", "sky_high_chip"],
            "sea": ["sea_main", "sea_near"],
            "debris": ["debris_central", "debris_cluster", "debris_tiny", "debris_low"],
            "shadows": ["shadow_central", "shadow_cluster", "shadow_low"],
            "note": "只读复制；本轮不改云形/速度/阴影规则。右桥脚不再使用 DS02 island_overlay。",
        },
        "masks_and_rebuild": {
            "G1_G2_geometry": "V6 纯几何定义（layer/solid/left/right）逐像素还原；完整墩体到 y=299，交付层保留到 y=299（end 300）；y≤282 为可见/潜在可见面，y283–299 为浮动 reserve（sea_main 顶边 260–282，全部相位不可见）；桥面 y205，拱洞保留",
            "G1_G2_visible": "V2 可见石质像素逐像素照搬（含 V2 的 818px 局部断口/接触影）；不使用 V1 砌缝",
            "G1_G2_hidden": "云色覆盖处按 V7 同一套石质调色还原；每列云顶以下到 y=299 用低对比石质空气色补齐，alpha 仍为 255；y283–299 是给桥体上浮用的实体 reserve，不是新增可见面，也不加不透明矩形",
            "G1": {"visible_px": g1_vis, "rebuilt_px": ext1,
                   "float_reserve_px": ext1_res, "reserve_mask_px": g1_res,
                   "extent": "y≤299（end 300），仅墩/拱/桥面实体列；可见到 y≤282，y283–299 为 reserve"},
            "G2": {"visible_px": g2_vis, "rebuilt_px": ext2,
                   "float_reserve_px": ext2_res, "reserve_mask_px": g2_res,
                   "gap_cut_px": gap_px, "gap_cut_over_column_px": gap_hidden,
                   "nub_to_G5_px": nub_transfer,
                   "note": "x474-482,y184-188 切空，柱顶 y189；被旧柱头盖住的岛底片段归 G5"},
            "G4_hidden": {"visible_px": g4_vis, "rebuilt_px": ext4,
                          "visible_contact_px": ext4_vis, "hidden_px": ext4_hidden,
                          "rule": "主桥面 y205 直接压住的列：y204 的 1px 天空线改成接触影（14px 可见，已解释），y205-209 在桥面后；G4 台基右端被 debris_central 遮住的 6px 用同行台基色补（静止时在岩石后）；断口凹槽里已可见的足部不补",
                          "reclassified_base_px": 333},
            "G3_G5": "全部为 V2 可见像素，不补绘；G5 含被柱头覆盖的岛底片段（避免隔离时出现矩形缺口）",
            "alpha": "所有建筑层二值 alpha（0/255）；不使用半透明羽化。桥脚雾化靠石质空气色 + 前置云遮挡，避免云下沉时出现透空鬼影",
            "cloud_palette_in_groups": cloud_rgb_in_groups,
            "arch_cloud_palette_px": arch_cloud_colors,
        },
        "safe_float": {
            "bridge_amp_max_px": 1.5,
            "far_ruins_amp_max_px": 0.8,
            "bridge_float_reserve": {
                "cut_end_y": 300,
                "previous_cut_end_y": 283,
                "reserve_px": 17,
                "worst_sea_main_top_y": 282,
                "G1": joint["G1_left_bridge"],
                "G2": joint["G2_right_bridge"],
                "rule": "sea_main 顶边最低 282；G1 上浮 1.5px（整数取整 -2）时桥体底边 298，G2 上浮 1.0px（整数 -1）时底边 299，均比最低云顶低 16–17px。交付 PNG 的 alpha 与 sea_main 实际 mask 联合检查：桥墩区从可见石面到前云无 sky 像素、无可见硬矩形底边。旧版裁到 end 283 会在 G1 上浮时露出 0.5–1px 天空缝，故不能靠减小上浮或云位移规避。",
            },
            "G5_G2": {
                "static_air_px": air_rest[0],
                "worst_integer_air_px": air_worst[0],
                "min_2d_distance_px_worst": air_worst[1],
                "rule": "G2≤1.0px、G5≤1.5px 时任意相位相对位移≤2.5px，5px 空气至少剩 2.5px；整数取整极端 G5+2/G2-1 仍剩 2px。更稳的做法是 G5 与 G2 同周期同相（相对≤0.5px）。若工程把 G2 提到 1.5px，必须同相或把 |dyG5-dyG2| 限制在 ≤3px。",
            },
            "G3_G1": "G3 岛底 y199 与左桥面 y205 静止 5px；G3 0.8 + G1 1.5 的相对极值 2.3px，最小 2.7px，无接触",
            "G4_G1": "G4 足部补面到 y209；G4 0.6 + G1 1.5 的相对极值 2.1px，补面仍有余量",
            "canvas": "所有组 bbox 加 1.5px 浮动均在 640x360 内；最上 G5 y138、最下 G1/G2 y299（end 300，其中 y283–299 为不可见浮动 reserve）",
        },
        "checks": {
            "reference_is_not_delivery": "03_reference_overlay 使用 DS02 t=0 静态云海，只作叠回检查，不是动态完成声明",
            "v2_visible_pixel_diff": has_mm,
            "v2_visible_pixels": int(vis_any.sum()),
            "intentional_visible_rebuilt_px": intentional_contact,
            "right_foot_static_px_diff": right_foot_static_diff,
            "v2_visible_diff_note": "G4 左端 14px 的 y204 天空线改为接触影（补院落足部）；其余 V2 可见建筑像素 0 差异；红=未解释差异，琥珀=已解释接触影",
            "joint_pier_float_extreme": {
                "check": "13_pier_float_reserve_joint_extreme_10x.png",
                "method": "读交付 G1/G2 PNG 的 alpha，按 G1 整数 -2 / G2 整数 -1（最大上浮取整）放置；读 sea_main 同相位实际 mask 的每列首个不透明 y；对 V6 实体桥墩列做 mask 连续性与合成 sky 像素检查。G1 的 -1.5 浮点底边为 298.5，比整数 -2 的 298 多 0.5px 余量。",
                "reserve_pixels_uncovered_by_sea_main_at_t0": reserve_uncovered,
                "G1": joint["G1_left_bridge"],
                "G2": joint["G2_right_bridge"],
                "result": "两桥墩区从可见石面到前云 mask 连续，合成图中 sky 像素 0；底边 298/299 比最低云顶 282 低 16–17px，硬矩形底边不可见。旧版 end 283 在 G1 x49、dy=-2 时实测露 1px sky（y281），本版为 0。",
            },
            "reference_vs_v2": {
                "differing_px": dm_total,
                "fraction": round(dm_total / (W * H), 4),
                "above_y250_px": dm_above,
                "diff_bbox": diff_bbox,
                "cause": "DS02 的 sea_main/sea_near 是重建的连续云海纹理；205–250 的差主要是 DS02 浮石在 t=0 的相位位移（cluster/central），右桥脚改由前置云海遮挡；不是建筑层改动",
            },
            "files": sorted(p.name for p in CHECK_DIR.iterdir() if p.suffix == ".png"),
        },
        "inspected": [
            "已打开 V2 640 原图、DS02 island_overlay、左右桥/远院落/右岛岩底 5–12× 局部",
            "已打开本目录 640 参考叠图、洋红隔离图、左右桥同层遮挡、右桥脚 before/after、G5/G2 极值 10×、G4/G1 极值 10×",
            "已打开 13 联合极值 10×：G1 dy=-2 / G2 dy=-1 与 sea_main 云顶 282 同帧，桥墩到前云 mask 连续",
        ],
        "unverified": [
            "未实现最终动画/相位/时间系统/离线 HTML；由 1 号工程完成",
            "未接 Godot、无引擎截图或连续试玩",
            "参考叠图用的是 DS02 t=0 云海，云顶与 V2 原图有 1–3px 平滑差；未做逐帧运动可读性验收",
            "未合成前景人物/UI；未验证 640 以下小尺寸的 5px 空气读法",
            "G5 岛底在 x474-482 的 1px 灯色片段沿用 V2 柱头像素，静止时可读为岩面；未重绘为暗色岩底以免改变已认可轮廓",
            "13 联合极值用交付 PNG alpha + sea_main 同相位 mask 做数值/合成验证；未在引擎内验证 1.5px 亚像素采样，整数取整 -2 已按更严方向覆盖",
        ],
    }
    (HERE / "art_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("G1 visible/hidden:", g1_vis, ext1, "reserve", ext1_res, "/", g1_res)
    print("G2 visible/hidden:", g2_vis, ext2, "reserve", ext2_res, "/", g2_res,
          "gap", gap_px, "nub transfer", nub_transfer)
    print("G4 visible/hidden:", g4_vis, ext4)
    print("arch px", int(info["arch"].sum()), "static px", int(info["static"].sum()))
    print("G5/G2 air rest", air_rest, "worst", air_worst)
    print("joint pier reserve:", json.dumps(joint, ensure_ascii=False))
    print("right foot static diff px:", right_foot_static_diff)
    print("V2 visible diff", has_mm, "of", int(vis_any.sum()))
    print("ref vs V2", dm_total, dm_above, diff_bbox)
    for y0, y1 in ((0, 130), (130, 205), (205, 250), (250, 282), (282, 360)):
        seg = dm[y0:y1]
        print(f"  diff y{y0}-{y1}: {int(seg.sum())}")
    print("baseline files", len(prot_before), "unchanged")
    print("output:", HERE)


if __name__ == "__main__":
    main()
