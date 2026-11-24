# -*- coding: utf-8 -*-
"""DS01 trial: split the approved V7 cloud-ruins background into a small,
auditable layer set.  Read-only with respect to every old asset/script.

Everything written by this script stays inside this directory:
自制素材/云海遗迹背景拆层试作_DS01/
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw
from scipy import ndimage

BASE = Path(__file__).resolve().parent
CONCEPT = BASE.parent / "云海遗迹背景概念示意"
PROJECT = BASE.parent.parent
SRC_CONCEPT = CONCEPT / "background_only_v7.png"
SRC_PROJECT = PROJECT / "基础场景原型" / "assets" / "backgrounds" / "cloud_ruins_v7.png"
V6_GENERATOR = CONCEPT / "generate_background_v6.py"
BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\background-layer-ds01-baseline-886530197b5e45eca39d5c50bb3382fb\hashes.json"
)

W, H = 640, 360
PAD = 8            # cloud-sea side margin
SKY_PAD = 12       # sky-cloud side margin; covers dx 6 with spare and the 2x sheet
LAYERS = BASE / "layers"
CHECKS = BASE / "checks"

CLOUD8 = [
    (133, 173, 181), (148, 186, 191), (142, 181, 187), (151, 189, 193),
    (164, 198, 201), (157, 192, 197), (135, 174, 182), (148, 184, 190),
]
FAR_COLORS = {(133, 173, 181), (135, 174, 182)}
NEAR_COLORS = set(CLOUD8) - FAR_COLORS
FAR_TONE = (133, 173, 181)
DEEP_TONE = (148, 186, 191)

# V7 stone palette, used only to reconstruct the bridge behind the cloud sea.
STONE = (67, 94, 116); SHADE = (48, 74, 97); LIGHT = (101, 128, 145)
MID = (82, 110, 132); JOINT = (55, 82, 104); EDGE = (112, 139, 153)
V7_PALETTE = {
    STONE: (94, 122, 138), SHADE: (82, 110, 128),
    LIGHT: (113, 139, 151), MID: (101, 128, 143),
    JOINT: (91, 119, 135), EDGE: (118, 144, 154),
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sky_array() -> np.ndarray:
    yy = np.arange(H)[:, None]
    t = np.minimum(yy, 315) / 315.0
    row = np.stack([
        np.round(45 + 75 * t), np.round(90 + 75 * t), np.round(112 + 62 * t)
    ], axis=2).astype(np.int16)
    return np.broadcast_to(row, (H, W, 3)).copy()


def load_source() -> tuple[np.ndarray, dict]:
    concept = Image.open(SRC_CONCEPT).convert("RGB")
    assert concept.size == (1280, 720)
    src = np.array(concept.resize((W, H), Image.Resampling.NEAREST)).astype(np.uint8)
    project = np.array(Image.open(SRC_PROJECT).convert("RGB")).astype(np.uint8)
    assert project.shape == src.shape
    assert np.array_equal(project, src), "project 640 image must equal V7 logical pixels"
    return src, {
        "concept_png": str(SRC_CONCEPT),
        "concept_size": [1280, 720],
        "project_png": str(SRC_PROJECT),
        "project_size": [W, H],
        "project_equals_concept_640_nearest": True,
        "concept_sha256": sha256(SRC_CONCEPT),
        "project_sha256": sha256(SRC_PROJECT),
    }


def execute_v6_geometry() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Read (never run) the V6 generator; execute only its pure drawing slice."""
    text = V6_GENERATOR.read_text(encoding="utf-8")
    geometry = text[text.index("layer=Image.new('RGBA'"):text.index("im.paste(layer,")]
    ns = dict(Image=Image, ImageDraw=ImageDraw, ImageChops=ImageChops, math=math,
              STONE=STONE, SHADE=SHADE, LIGHT=LIGHT, MID=MID, JOINT=JOINT, EDGE=EDGE)
    exec(compile(geometry, "v6_geometry_only", "exec"), ns)
    layer = np.array(ns["layer"].convert("RGBA")).astype(np.uint8)
    solid = (np.array(ns["solid"]) > 0)
    return layer, solid, np.array(layer[..., :3]).astype(np.uint8)


def v7_stone_from_old(old: tuple[int, int, int], x: int, y: int) -> tuple[int, int, int]:
    stone = V7_PALETTE[old]
    if y < 205:
        stone = tuple(round(a * 0.22 + b * 0.78) for a, b in zip(old, stone))
    if old == JOINT and (y >= 220 or (x // 18) % 3 != 0):
        stone = (95, 123, 139)
    wave = (0, 2, 3, 1, -1, -2, -1, 1)[(x // 24) % 8]
    depth = y + wave
    fog = 0.0
    for start, amount in [(231, .08), (239, .18), (247, .31), (254, .46),
                          (260, .62), (266, .77), (272, .90), (279, 1.0)]:
        if depth >= start:
            fog = amount
    return tuple(round(a * (1 - fog) + b * fog) for a, b in zip(stone, (133, 173, 181)))


def reconstruct_bridge(src: np.ndarray, layer_rgb: np.ndarray, solid: np.ndarray) -> np.ndarray:
    """Hypothetical V7 stone colour for every bridge pixel, including hidden ones."""
    out = np.zeros_like(src)
    cache = {}
    palette = sorted({tuple(c) for c in src.reshape(-1, 3)})
    pal = np.array(palette, dtype=np.int16)
    for y, x in zip(*np.where(solid)):
        old = tuple(int(v) for v in layer_rgb[y, x])
        key = (old, x, y)
        if key not in cache:
            raw = v7_stone_from_old(old, x, y)
            # Keep the discrete source palette: snap a reconstructed flat step
            # to the nearest colour that already exists in V7.
            d = ((pal - np.array(raw, dtype=np.int16)) ** 2).sum(axis=1)
            cache[key] = palette[int(np.argmin(d))]
        out[y, x] = cache[key]
    return out


def build_masks(src: np.ndarray) -> tuple[dict[str, np.ndarray], np.ndarray]:
    sky = sky_array()
    yy = np.arange(H)[:, None]
    sky_g = np.broadcast_to(sky[:, :, 1], (H, W))
    is_cloud = np.zeros((H, W), bool)
    for c in CLOUD8:
        is_cloud |= np.all(src == c, axis=2)

    masks = {}
    # Sky clouds: exact per-pixel difference from the vertical sky gradient.
    m = np.zeros((H, W), bool)
    for y in range(125):
        m[y] = np.any(src[y] != sky[y], axis=1)
    masks["sky_clouds"] = m

    # Cloud sea: the eight existing V6 cloud flats, split into two depth bands.
    masks["cloud_sea_far"] = np.zeros((H, W), bool)
    masks["cloud_sea_near"] = np.zeros((H, W), bool)
    for c in FAR_COLORS:
        masks["cloud_sea_far"] |= np.all(src == c, axis=2)
    for c in NEAR_COLORS:
        masks["cloud_sea_near"] |= np.all(src == c, axis=2)
    assert not np.any(masks["cloud_sea_far"] & masks["cloud_sea_near"])
    assert np.array_equal(masks["cloud_sea_far"] | masks["cloud_sea_near"], is_cloud)

    def largest_component(mask, min_area, bbox):
        x0, y0, x1, y1 = bbox
        sub = mask[y0:y1, x0:x1]
        lab, n = ndimage.label(sub, structure=np.ones((3, 3)))
        best = None
        for i, sl in enumerate(ndimage.find_objects(lab), 1):
            if sl is None:
                continue
            area = int((lab[sl] == i).sum())
            if area < min_area:
                continue
            if best is None or area > best[0]:
                best = (area, i, sl)
        assert best is not None, bbox
        out = np.zeros((H, W), bool)
        area, i, sl = best
        out[y0:y0 + sub.shape[0], x0:x0 + sub.shape[1]][lab == i] = True
        return ndimage.binary_fill_holes(out)

    # Central large shard.
    box = (296, 200, 344, 258)
    x0, y0, x1, y1 = box
    sub = src[y0:y1, x0:x1]
    ss = sky[y0:y1, x0:x1]
    m = (sub[:, :, 1] < ss[:, :, 1] - 3) & ~is_cloud[y0:y1, x0:x1]
    full = np.zeros((H, W), bool)
    full[y0:y1, x0:x1] = m
    masks["debris_central"] = largest_component(full, 100, box)

    # Lower-left cluster: two adjacent shards grouped as one small layer.
    box = (258, 238, 300, 270)
    x0, y0, x1, y1 = box
    sub = src[y0:y1, x0:x1]
    ss = sky[y0:y1, x0:x1]
    m = (sub[:, :, 1] < ss[:, :, 1] - 3) & ~is_cloud[y0:y1, x0:x1]
    full = np.zeros((H, W), bool)
    full[y0:y1, x0:x1] = m
    lab, n = ndimage.label(full, structure=np.ones((3, 3)))
    keep = np.zeros((H, W), bool)
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is not None and int((lab[sl] == i).sum()) >= 10:
            keep |= lab == i
    masks["debris_cluster"] = ndimage.binary_fill_holes(keep)

    # Tiny right-hand chip.
    box = (372, 228, 394, 252)
    x0, y0, x1, y1 = box
    sub = src[y0:y1, x0:x1]
    ss = sky[y0:y1, x0:x1]
    m = (sub[:, :, 1] < ss[:, :, 1] - 3) & ~is_cloud[y0:y1, x0:x1]
    full = np.zeros((H, W), bool)
    full[y0:y1, x0:x1] = m
    masks["debris_tiny"] = largest_component(full, 20, box)

    # Near-low rock: the cloud is opaque, so the largest non-cloud component is
    # the unambiguous standalone rock.  The 5-pixel speckle below it stays static.
    box = (222, 286, 272, 334)
    x0, y0, x1, y1 = box
    full = np.zeros((H, W), bool)
    full[y0:y1, x0:x1] = ~is_cloud[y0:y1, x0:x1]
    masks["debris_low"] = largest_component(full, 60, box)

    # Keep only the small set of unambiguous floating shards.  The shard touching
    # the broken column and the pale far slab remain in the static base.
    for key in ("debris_central", "debris_cluster", "debris_tiny", "debris_low"):
        assert masks[key].sum() > 0
    return masks, is_cloud


def row_gap_fill(src: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """Fill a row-shaped hole with the nearest existing colour on each side.

    No interpolation, blur or new RGB values are introduced.
    """
    out = src.copy()
    for y in range(H):
        xs = np.where(mask[y])[0]
        if xs.size == 0:
            continue
        runs = []
        start = prev = int(xs[0])
        for x in xs[1:]:
            x = int(x)
            if x == prev + 1:
                prev = x
            else:
                runs.append((start, prev))
                start = prev = x
        runs.append((start, prev))
        for x0, x1 in runs:
            l = x0 - 1
            while l >= 0 and mask[y, l]:
                l -= 1
            r = x1 + 1
            while r < W and mask[y, r]:
                r += 1
            lc = out[y, l] if l >= 0 else (out[y, r] if r < W else out[y, x0])
            rc = out[y, r] if r < W else lc
            mid = (x0 + x1 + 1) // 2
            out[y, x0:mid] = lc
            out[y, mid:x1 + 1] = rc
    return out


def build_base(src: np.ndarray, masks: dict[str, np.ndarray], solid: np.ndarray,
               stone: np.ndarray) -> np.ndarray:
    sky = sky_array()
    base = src.copy()
    # Sky clouds: exact vertical gradient.
    base[masks["sky_clouds"]] = sky[masks["sky_clouds"]]

    # Floating shards over open sky.
    for key in ("debris_central", "debris_cluster", "debris_tiny"):
        base = row_gap_fill(base, masks[key])
    # Low rock sits over cloud; fill from the nearest cloud/sea rows.
    base = row_gap_fill(base, masks["debris_low"])

    far = masks["cloud_sea_far"]
    near = masks["cloud_sea_near"]
    top_far = np.full(W, 260, dtype=np.int16)
    for x in range(W):
        ys = np.where(far[:, x])[0]
        if ys.size:
            top_far[x] = ys.min()
    yy = np.arange(H)[:, None]
    # Behind the upper dark band: sky at its 4-pixel crest, a lighter cloud body
    # below, and the reconstructed bridge wherever the pier is hidden.
    under_far = np.broadcast_to(np.array(DEEP_TONE, np.uint8), (H, W, 3)).copy()
    crest = yy < (top_far[None, :] + 4)
    under_far[crest] = sky[crest]
    under_far[solid] = stone[solid]
    base[far] = under_far[far]

    # Behind the near light band: the far tone, which is the same tone as the
    # fogged pier bottoms at these depths.  No duplicate light band is stored.
    under_near = np.broadcast_to(np.array(FAR_TONE, np.uint8), (H, W, 3)).copy()
    under_near[solid] = stone[solid]
    base[near] = under_near[near]

    # Palette discipline: a hidden fill may land on a gradient step that was
    # fully occluded in V7.  Snap such a step to the nearest colour that already
    # exists in V7, so no new RGB value is introduced anywhere.
    palette = sorted({tuple(int(v) for v in c) for c in src.reshape(-1, 3)})
    pal = np.array(palette, dtype=np.int16)
    src_set = set(palette)
    cache = {}
    for y in range(H):
        for x in range(W):
            c = tuple(int(v) for v in base[y, x])
            if c in src_set:
                continue
            if c not in cache:
                d = ((pal - np.array(c, dtype=np.int16)) ** 2).sum(axis=1)
                cache[c] = palette[int(np.argmin(d))]
            base[y, x] = cache[c]
    return base


def rgba_from_mask(src: np.ndarray, mask: np.ndarray) -> np.ndarray:
    out = np.zeros((H, W, 4), np.uint8)
    out[..., :3] = src
    out[..., 3] = mask.astype(np.uint8) * 255
    out[~mask, :3] = 0
    return out


def crop_rgba(src: np.ndarray, mask: np.ndarray) -> tuple[np.ndarray, tuple[int, int, int, int]]:
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1
    sub = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    sub[..., :3] = src[y0:y1, x0:x1]
    sub[..., 3] = mask[y0:y1, x0:x1].astype(np.uint8) * 255
    sub[sub[..., 3] == 0, :3] = 0
    return sub, (x0, y0, x1, y1)


def fill_hidden_sea(src: np.ndarray, far_rgba: np.ndarray, near_rgba: np.ndarray,
                    low_mask: np.ndarray) -> tuple[np.ndarray, np.ndarray, int]:
    """Rebuild the two cloud tones under the low rock only.

    The rock is in front of the sea.  Its pixels are a hole in both sea layers;
    filling that hole means the rock can bob without exposing a flat patch or a
    sky-coloured void.  Colours are copied from the nearest sea pixel on each
    row (split at the run midpoint), so the existing discrete tones are kept.
    """
    far = far_rgba.copy()
    near = near_rgba.copy()
    is_sea = np.zeros((H, W), bool)
    for c in CLOUD8:
        is_sea |= np.all(src == c, axis=2)
    filled = 0
    for y in range(H):
        xs = np.where(low_mask[y])[0]
        if xs.size == 0:
            continue
        start = prev = int(xs[0])
        runs = []
        for x in xs[1:]:
            x = int(x)
            if x == prev + 1:
                prev = x
            else:
                runs.append((start, prev))
                start = prev = x
        runs.append((start, prev))
        for x0, x1 in runs:
            l = x0 - 1
            while l >= 0 and low_mask[y, l]:
                l -= 1
            lc = None
            while l >= 0:
                if is_sea[y, l]:
                    lc = tuple(int(v) for v in src[y, l])
                    break
                l -= 1
            r = x1 + 1
            while r < W and low_mask[y, r]:
                r += 1
            rc = None
            while r < W:
                if is_sea[y, r]:
                    rc = tuple(int(v) for v in src[y, r])
                    break
                r += 1
            if lc is None and rc is None:
                continue
            if lc is None:
                lc = rc
            if rc is None:
                rc = lc
            mid = (x0 + x1 + 1) // 2
            for x in range(x0, x1 + 1):
                c = lc if x < mid else rc
                assert c in CLOUD8
                if c in FAR_COLORS:
                    far[y, x, :3] = c
                    far[y, x, 3] = 255
                    near[y, x, 3] = 0
                else:
                    near[y, x, :3] = c
                    near[y, x, 3] = 255
                    far[y, x, 3] = 0
                filled += 1
    return far, near, filled


def pad_sea_layer(rgba: np.ndarray) -> np.ndarray:
    out = np.zeros((H, W + 2 * PAD, 4), np.uint8)
    out[:, PAD:PAD + W] = rgba
    out[:, :PAD] = rgba[:, :1]
    out[:, PAD + W:] = rgba[:, -1:]
    return out


def pad_sky_layer(rgba: np.ndarray) -> np.ndarray:
    """Continue the sky-cloud edges horizontally, without touching the canvas.

    V7 crops both sky-cloud banks at x=0/x=639.  At dx=+6 the cropped left
    column would land inside the viewport as a vertical 16px cut.  The side
    margin repeats the edge column (alpha and RGB) so the bank still runs off
    frame; the original 640 columns are byte-identical and are pasted at x=0
    by the initial offset -SKY_PAD.
    """
    out = np.zeros((H, W + 2 * SKY_PAD, 4), np.uint8)
    out[:, SKY_PAD:SKY_PAD + W] = rgba
    out[:, :SKY_PAD] = rgba[:, :1]
    out[:, SKY_PAD + W:] = rgba[:, -1:]
    return out


def save_png(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(path, optimize=True)


def compose(stack: list[dict], offsets: dict[str, tuple[int, int]] | None = None) -> np.ndarray:
    offsets = offsets or {}
    base = stack[0]["image"]
    canvas = Image.fromarray(base, "RGB").convert("RGBA")
    for item in stack[1:]:
        im = Image.fromarray(item["image"], "RGBA")
        dx, dy = offsets.get(item["name"], (0, 0))
        ox, oy = item["offset"]
        # paste with alpha mask works with negative origins and binary alpha
        canvas.paste(im, (ox + dx, oy + dy), im)
    return np.array(canvas.convert("RGB"))


def verify_protected() -> dict:
    data = json.loads(BASELINE.read_text(encoding="utf-8-sig"))
    rows = []
    for e in data:
        name = Path(e["path"].replace("\\", "/")).name
        cands = [CONCEPT / name] + list(PROJECT.rglob(name))
        cands = [p for p in cands if p.is_file()]
        matches = [p for p in cands if sha256(p) == e["sha256"].lower()]
        if not matches:
            rows.append({"basename": name, "baseline_sha256": e["sha256"],
                         "matched_path": None, "ok": False})
        else:
            p = matches[0]
            rows.append({"basename": name, "matched_path": str(p),
                         "baseline_sha256": e["sha256"], "before": sha256(p),
                         "after": None, "ok": True})
    return {
        "baseline": str(BASELINE),
        "note": "baseline JSON paths are mojibake; entries were matched by basename + SHA-256",
        "entries": rows,
    }


def main() -> None:
    LAYERS.mkdir(parents=True, exist_ok=True)
    CHECKS.mkdir(parents=True, exist_ok=True)
    protected = verify_protected()
    src, source_info = load_source()
    v6_layer, solid, layer_rgb = execute_v6_geometry()
    stone = reconstruct_bridge(src, layer_rgb, solid)
    masks, is_cloud = build_masks(src)
    base = build_base(src, masks, solid, stone)

    # Sky layer.  Its side margin only shows when the layer is displaced; the
    # canvas-aligned 640 columns stay identical to V7.
    sky_rgba = rgba_from_mask(src, masks["sky_clouds"])
    sky_padded = pad_sky_layer(sky_rgba)
    save_png(sky_padded, LAYERS / "sky_clouds.png")

    # Sea layers.
    far_rgba = rgba_from_mask(src, masks["cloud_sea_far"])
    near_rgba = rgba_from_mask(src, masks["cloud_sea_near"])
    far_rgba, near_rgba, hidden_sea_px = fill_hidden_sea(
        src, far_rgba, near_rgba, masks["debris_low"]
    )
    save_png(pad_sea_layer(far_rgba), LAYERS / "cloud_sea_far.png")
    save_png(pad_sea_layer(near_rgba), LAYERS / "cloud_sea_near.png")

    # Debris layers.
    debris = {}
    for key, fname in [
        ("debris_central", "debris_central.png"),
        ("debris_cluster", "debris_cluster.png"),
        ("debris_tiny", "debris_tiny.png"),
        ("debris_low", "debris_low.png"),
    ]:
        sub, bbox = crop_rgba(src, masks[key])
        debris[key] = {"image": sub, "bbox": bbox, "mask": masks[key]}
        save_png(sub, LAYERS / fname)

    save_png(base, LAYERS / "base_static.png")

    # Palette audit: every visible colour in every layer/base must already exist
    # in V7.  Hidden fill is included, so this is stricter than the composite.
    src_palette = {tuple(int(v) for v in c) for c in src.reshape(-1, 3)}
    palette_report = {}
    for name, arr in {
        "base_static": base,
        "sky_clouds": sky_padded,
        "cloud_sea_far": far_rgba,
        "cloud_sea_near": near_rgba,
        "debris_central": debris["debris_central"]["image"],
        "debris_cluster": debris["debris_cluster"]["image"],
        "debris_tiny": debris["debris_tiny"]["image"],
        "debris_low": debris["debris_low"]["image"],
    }.items():
        a = np.array(arr, dtype=np.uint8)
        if a.ndim == 3 and a.shape[2] == 4:
            rgb = a[..., :3][a[..., 3] > 0]
        else:
            rgb = a.reshape(-1, 3)
        cols = {tuple(int(v) for v in c) for c in rgb}
        new = sorted(cols - src_palette)
        palette_report[name] = {"visible_colours": len(cols), "new_colours": len(new)}
        assert not new, (name, new[:4])
    (CHECKS / "palette_check.json").write_text(
        json.dumps(palette_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    stack = [
        {"name": "base_static", "image": base, "offset": (0, 0),
         "file": "layers/base_static.png", "size": [W, H], "order": 0},
        {"name": "sky_clouds", "image": sky_padded, "offset": (-SKY_PAD, 0),
         "file": "layers/sky_clouds.png", "size": [W + 2 * SKY_PAD, H], "order": 1},
        {"name": "cloud_sea_far", "image": pad_sea_layer(far_rgba), "offset": (-PAD, 0),
         "file": "layers/cloud_sea_far.png", "size": [W + 2 * PAD, H], "order": 2},
        {"name": "cloud_sea_near", "image": pad_sea_layer(near_rgba), "offset": (-PAD, 0),
         "file": "layers/cloud_sea_near.png", "size": [W + 2 * PAD, H], "order": 3},
    ]
    for i, key in enumerate(["debris_central", "debris_cluster", "debris_tiny", "debris_low"], 4):
        d = debris[key]
        x0, y0, x1, y1 = d["bbox"]
        stack.append({
            "name": key, "image": d["image"], "offset": (x0, y0),
            "file": f"layers/{key}.png", "size": [x1 - x0, y1 - y0], "order": i,
        })

    comp = compose(stack)
    save_png(comp, BASE / "reassembled.png")
    diff = np.abs(comp.astype(np.int16) - src.astype(np.int16))
    diff_count = int(np.any(diff != 0, axis=2).sum())
    diff_max = int(diff.max())
    diff_mask = np.any(diff != 0, axis=2)
    bbox = None
    if diff_count:
        ys, xs = np.where(diff_mask)
        bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    diff_vis = np.zeros((H, W, 3), np.uint8)
    if diff_count:
        amp = np.clip(diff.max(axis=2) * 16, 0, 255).astype(np.uint8)
        diff_vis[..., 0] = amp
    save_png(diff_vis, BASE / "diff_vs_v7.png")
    stats = {
        "canvas": [W, H],
        "pixels": W * H,
        "differing_pixels": diff_count,
        "max_channel_difference": diff_max,
        "diff_bbox": bbox,
        "exact_match": diff_count == 0,
        "method": "composite all layers at their initial offsets; compare RGB to V7 640 logical pixels",
        "note": "zero difference proves static reassembly only, not inpainting/motion quality",
    }
    (BASE / "diff_vs_v7_stats.json").write_text(
        json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    assert diff_count == 0, f"reassembly not exact: {diff_count} pixels"

    # Documentation overlay.
    dim = (src.astype(np.float32) * 0.45).astype(np.uint8)
    overlay = Image.fromarray(dim, "RGB").convert("RGBA")
    colors = {
        "sky_clouds": (0, 235, 235, 105),
        "cloud_sea_far": (30, 90, 255, 80),
        "cloud_sea_near": (120, 190, 255, 90),
        "debris_central": (255, 120, 0, 150),
        "debris_cluster": (255, 120, 0, 150),
        "debris_tiny": (255, 120, 0, 150),
        "debris_low": (255, 120, 0, 150),
    }
    for key, col in colors.items():
        m = masks[key]
        layer = Image.new("RGBA", (W, H), col)
        overlay = Image.composite(layer, overlay, Image.fromarray((m * 255).astype(np.uint8)))
    # hidden sea rebuild under the low rock: show it as an outline so the orange
    # extracted-rock pixels remain readable in the same diagram.
    hidden_edge = masks["debris_low"] & ~ndimage.binary_erosion(masks["debris_low"])
    layer = Image.new("RGBA", (W, H), (255, 0, 255, 190))
    overlay = Image.composite(layer, overlay, Image.fromarray((hidden_edge * 255).astype(np.uint8)))
    out = Image.new("RGBA", (W * 2, H * 2 + 28), (20, 24, 28, 255))
    out.paste(overlay.resize((W * 2, H * 2), Image.Resampling.NEAREST), (0, 28))
    d = ImageDraw.Draw(out)
    d.text((8, 8), "cyan=sky clouds  blue=sea far  light=sea near  orange=debris  magenta outline=cloud rebuilt under low rock",
           fill=(230, 235, 240, 255))
    out.convert("RGB").save(CHECKS / "mask_overlay.png", optimize=True)

    # Layer metadata / manifest.
    def mask_info(key):
        m = masks[key]
        ys, xs = np.where(m)
        return {
            "pixels": int(m.sum()),
            "bbox": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1],
        }

    manifest = {
        "name": "云海遗迹背景拆层试作_DS01",
        "status": "trial, not integrated",
        "canvas": [W, H],
        "source": source_info,
        "stack_order": [
            {"order": 0, "name": "base_static", "file": "layers/base_static.png",
             "size": [W, H], "initial_offset": [0, 0], "kind": "static base"},
            {"order": 1, "name": "sky_clouds", "file": "layers/sky_clouds.png",
             "size": [W + 2 * SKY_PAD, H], "initial_offset": [-SKY_PAD, 0],
             "kind": "sky cloud alpha",
             "safe_range": {"dx": 6, "dy": 0},
             "padding": {"left": SKY_PAD, "right": SKY_PAD,
                         "method": "horizontal continuation of the edge column (alpha + RGB); original 640 columns unchanged"}},
            {"order": 2, "name": "cloud_sea_far", "file": "layers/cloud_sea_far.png",
             "size": [W + 2 * PAD, H], "initial_offset": [-PAD, 0],
             "kind": "upper dark cloud-sea band", "safe_range": {"dx": 2, "dy": 1}},
            {"order": 3, "name": "cloud_sea_near", "file": "layers/cloud_sea_near.png",
             "size": [W + 2 * PAD, H], "initial_offset": [-PAD, 0],
             "kind": "near light cloud-sea band", "safe_range": {"dx": 4, "dy": 0}},
            {"order": 4, "name": "debris_central", "file": "layers/debris_central.png",
             "size": list(debris["debris_central"]["image"].shape[1::-1]),
             "initial_offset": list(debris["debris_central"]["bbox"][:2]),
             "kind": "floating shard", "safe_range": {"dx": 1, "dy": 2}},
            {"order": 5, "name": "debris_cluster", "file": "layers/debris_cluster.png",
             "size": list(debris["debris_cluster"]["image"].shape[1::-1]),
             "initial_offset": list(debris["debris_cluster"]["bbox"][:2]),
             "kind": "two small floating shards", "safe_range": {"dx": 1, "dy": 1}},
            {"order": 6, "name": "debris_tiny", "file": "layers/debris_tiny.png",
             "size": list(debris["debris_tiny"]["image"].shape[1::-1]),
             "initial_offset": list(debris["debris_tiny"]["bbox"][:2]),
             "kind": "tiny floating chip", "safe_range": {"dx": 0, "dy": 1}},
            {"order": 7, "name": "debris_low", "file": "layers/debris_low.png",
             "size": list(debris["debris_low"]["image"].shape[1::-1]),
             "initial_offset": list(debris["debris_low"]["bbox"][:2]),
             "kind": "low floating rock in front of sea", "safe_range": {"dx": 1, "dy": 1}},
        ],
        "masks": {k: mask_info(k) for k in [
            "sky_clouds", "cloud_sea_far", "cloud_sea_near",
            "debris_central", "debris_cluster", "debris_tiny", "debris_low"]},
        "hidden_cloud_under_low_rock_pixels": hidden_sea_px,
        "bridge_reconstructed_pixels": int(
            (solid & (masks["cloud_sea_far"] | masks["cloud_sea_near"])).sum()
        ),
        "notes": {
            "sea_split": "two sublayers only: upper dark band and near light band; they occlude at their shared contour and need different speeds",
            "sky_edge_padding": f"{SKY_PAD}px horizontal continuation on the sky-cloud layer; initial offset -{SKY_PAD} keeps V7 alignment. At dx=6 the margin|original boundary sits at screen x=6, but both sides repeat the same edge column, so no cut edge or sky strip is visible; 6px of margin stays on each side",
            "edge_padding": f"{PAD}px horizontal edge-clamp margin on sea layers; initial offset -{PAD} keeps V7 alignment",
            "static_kept": "bridges, columns, left island/courtyard, right floating temple island, cloud arches, pale far slab, shard touching broken column",
            "inpaint": "base under extracted masks + cloud tones rebuilt under the low rock; only originally occluded pixels",
        },
    }
    (BASE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # Re-verify protected files after writing.
    for row in protected["entries"]:
        if row.get("matched_path"):
            row["after"] = sha256(Path(row["matched_path"]))
            row["ok"] = row["after"] == row["baseline_sha256"].lower() == row.get("before")
    (CHECKS / "protected_hashes_check.json").write_text(
        json.dumps(protected, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    assert all(r["ok"] for r in protected["entries"]), "protected file changed or unresolved"

    print("layers written:", len(stack), "stack entries")
    print("extracted:", {k: v["pixels"] for k, v in manifest["masks"].items()})
    print("hidden sea under low rock:", hidden_sea_px)
    print("reassembly diff:", diff_count, "max", diff_max)
    print("protected baseline entries:", len(protected["entries"]),
          "all ok:", all(r["ok"] for r in protected["entries"]))


if __name__ == "__main__":
    main()
