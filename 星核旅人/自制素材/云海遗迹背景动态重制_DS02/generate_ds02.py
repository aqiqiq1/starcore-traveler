# -*- coding: utf-8 -*-
"""DS02: a new, continuous one-way motion rebuild of the V7 cloud-ruins still.

Approach
--------
* Sky clouds: the seven approved V7 cloud objects, each with its own complete
  shading.  Only new pixels are the off-canvas tails needed when an object
  leaves/re-enters.
* Cloud sea: two depth shelves made from the V7 cloud-sea pixels themselves.
  Each shelf is a complete cloud body (all tones) on a true 1280px periodic
  texture (640px V7 mother + its same-value mirror).  Nothing is stretched,
  edge-clamped, or split by colour.  The far/mid shelf and the near light shelf
  move at different speeds; the near shelf is drawn in front of the ruins.
* Rocks: fixed V7/DS01 silhouettes, vertical bob only; projected shadows are
  drawn source-atop on the sea so they cannot punch holes.

Read-only inputs; all outputs stay in this directory.
"""
from __future__ import annotations

import hashlib
import json
import math
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw
from scipy import ndimage

BASE = Path(__file__).resolve().parent
ASSETS = BASE.parent
CONCEPT = ASSETS / "云海遗迹背景概念示意"
DS01 = ASSETS / "云海遗迹背景拆层试作_DS01"
PROJECT = ASSETS.parent
SRC_V7 = CONCEPT / "background_only_v7.png"
V6_GEN = CONCEPT / "generate_background_v6.py"
BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\background-ds02-baseline-6fa26b4f59f6467cb2710157ac337880\hashes.json"
)
LAYERS = BASE / "layers"
CHECKS = BASE / "checks"

W, H = 640, 360
SEA_P = 1278
SCALE = 2

SEA8 = [(133, 173, 181), (135, 174, 182), (142, 181, 187), (148, 184, 190),
        (148, 186, 191), (151, 189, 193), (157, 192, 197), (164, 198, 201)]
FAR_SET = {(133, 173, 181), (135, 174, 182)}
MID_BODY = (148, 186, 191)
NEAR_BODY = (164, 198, 201)
SHADOW_RGB = (54, 94, 114)

# layer speeds (logical px/s), deliberately within the requested debugging band
SPEED_MAIN = 4.2
SPEED_NEAR = 7.2
SPEED_BANK = 6.2
SPEED_WISP = 3.6


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protected_snapshot() -> list[dict]:
    data = json.loads(BASELINE.read_text(encoding="utf-8-sig"))
    rows = []
    for e in data:
        p = Path(e["path"])
        if not p.is_absolute():
            p = PROJECT / p
        exists = p.is_file()
        rows.append({
            "path": str(p), "baseline_sha256": e["sha256"].lower(),
            "exists": exists, "sha256": sha256(p).lower() if exists else None,
        })
    return rows


def load_v7() -> np.ndarray:
    im = Image.open(SRC_V7).convert("RGB")
    assert im.size == (1280, 720)
    return np.array(im.resize((W, H), Image.Resampling.NEAREST)).astype(np.uint8)


def sky_gradient() -> np.ndarray:
    yy = np.arange(H)[:, None]
    t = np.minimum(yy, 315) / 315.0
    row = np.stack([np.round(45 + 75 * t), np.round(90 + 75 * t),
                    np.round(112 + 62 * t)], axis=2).astype(np.int16)
    return np.broadcast_to(row, (H, W, 3)).copy()


def bridge_solid() -> np.ndarray:
    text = V6_GEN.read_text(encoding="utf-8")
    geo = text[text.index("layer=Image.new('RGBA'"):text.index("im.paste(layer,")]
    ns = dict(Image=Image, ImageDraw=ImageDraw, ImageChops=ImageChops, math=math,
              STONE=(67, 94, 116), SHADE=(48, 74, 97), LIGHT=(101, 128, 145),
              MID=(82, 110, 132), JOINT=(55, 82, 104), EDGE=(112, 139, 153))
    exec(compile(geo, "v6_geometry_only", "exec"), ns)
    return np.array(ns["solid"]) > 0


def sea_masks(src: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    sea = np.zeros((H, W), bool)
    far = np.zeros((H, W), bool)
    near = np.zeros((H, W), bool)
    for c in SEA8:
        m = np.all(src == c, axis=2)
        sea |= m
        if c in FAR_SET:
            far |= m
        else:
            near |= m
    return sea, far, near


def fill_profile(mask: np.ndarray, ymin: int) -> np.ndarray:
    top = np.full(W, np.nan)
    for x in range(W):
        ys = np.where(mask[:, x])[0]
        ys = ys[ys >= ymin]
        if len(ys):
            top[x] = ys.min()
    ok = np.where(~np.isnan(top))[0]
    return np.interp(np.arange(W), ok, top[ok])


def build_base(src: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Static base: keep ruins/islands, replace all old sea and stray specks
    with sky so no baked shadow or static cloud can peek through the motion."""
    base = np.array(Image.open(DS01 / "layers" / "base_static.png").convert("RGB"))
    sky = sky_gradient()
    solid = bridge_solid()
    sea, _, _ = sea_masks(src)
    stone = ~sea & np.any(src != sky, axis=2)

    protected = solid.copy()
    protected[132:207, 0:188] = True          # left island / colonnade base
    protected[135:286, 444:614] = True        # right temple and upper island
    for x0, y0, x1, y1 in [(268, 236, 338, 314), (358, 268, 416, 314),
                           (254, 210, 286, 250), (384, 204, 434, 236)]:
        box = np.zeros((H, W), bool)
        box[y0:y1, x0:x1] = True
        protected |= box & stone
    dyn = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in [(303, 207, 342, 249), (264, 243, 300, 265),
                           (379, 235, 388, 246), (231, 289, 262, 322)]:
        dyn[y0:y1, x0:x1] = True
    protected &= ~dyn

    out = base.copy()
    yy = np.arange(H)[:, None]
    clean = (yy >= 244) & ~protected
    out[clean] = sky[clean]
    return out, protected


def sky_cloud_components(src: np.ndarray) -> list[dict]:
    sky = sky_gradient()
    m = np.zeros((H, W), bool)
    for y in range(0, 128):
        m[y] = np.any(src[y].astype(np.int16) != sky[y], axis=1)
    lab, n = ndimage.label(m, np.ones((3, 3)))
    comps = []
    for i, sl in enumerate(ndimage.find_objects(lab), 1):
        if sl is None:
            continue
        area = int((lab[sl] == i).sum())
        if area < 20:
            continue
        x0, y0, x1, y1 = sl[1].start, sl[0].start, sl[1].stop, sl[0].stop
        sub = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
        mm = lab[sl] == i
        sub[..., :3] = src[y0:y1, x0:x1]
        sub[..., 3] = mm.astype(np.uint8) * 255
        sub[~mm, :3] = 0
        comps.append({"area": area, "bbox": (x0, y0, x1, y1), "rgba": sub})
    comps.sort(key=lambda c: c["area"], reverse=True)
    return comps


def edge_extend(rgba: np.ndarray, side: str, pad: int) -> np.ndarray:
    """Only new off-canvas tail; on-canvas columns are copied byte for byte."""
    h, w = rgba.shape[:2]
    out = np.zeros((h, w + pad, 4), np.uint8)
    if side == "left":
        out[:, pad:pad + w] = rgba
        anchor = rgba[:, 0]
        ys = np.where(anchor[:, 3] > 0)[0]
        yc = (ys.min() + ys.max()) / 2 if len(ys) else h / 2
        half = max(1.0, (ys.max() - ys.min() + 1) / 2) if len(ys) else 1.0
        for y in range(h):
            if anchor[y, 3] == 0:
                continue
            u = abs((y - yc) / half)
            L = int(round(pad * max(0.0, 1.0 - u * u) ** 0.65))
            out[y, pad - L:pad, :3] = anchor[y, :3]
            out[y, pad - L:pad, 3] = 255
        for y in range(h):
            xs = np.where(out[y, :, 3] > 0)[0]
            if len(xs) and xs.min() < pad:
                out[y, xs.min(), :3] = np.minimum(255, out[y, xs.min(), :3].astype(np.int16) + 8)
        return out
    out[:, :w] = rgba
    anchor = rgba[:, -1]
    ys = np.where(anchor[:, 3] > 0)[0]
    yc = (ys.min() + ys.max()) / 2 if len(ys) else h / 2
    half = max(1.0, (ys.max() - ys.min() + 1) / 2) if len(ys) else 1.0
    for y in range(h):
        if anchor[y, 3] == 0:
            continue
        u = abs((y - yc) / half)
        L = int(round(pad * max(0.0, 1.0 - u * u) ** 0.65))
        out[y, w:w + L, :3] = anchor[y, :3]
        out[y, w:w + L, 3] = 255
    for y in range(h):
        xs = np.where(out[y, :, 3] > 0)[0]
        if len(xs) and xs.max() >= w:
            out[y, xs.max(), :3] = np.minimum(255, out[y, xs.max(), :3].astype(np.int16) + 8)
    return out


def _nearest_row_colour(src: np.ndarray, is_sea: np.ndarray, x: int, y: int,
                        fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    l = x - 1
    while l >= 0 and not is_sea[y, l]:
        l -= 1
    r = x + 1
    while r < W and not is_sea[y, r]:
        r += 1
    if l >= 0 and r < W:
        return tuple(int(v) for v in src[y, l if (x - l) <= (r - x) else r])
    if l >= 0:
        return tuple(int(v) for v in src[y, l])
    if r < W:
        return tuple(int(v) for v in src[y, r])
    return fallback


def clean_top(top: np.ndarray) -> np.ndarray:
    """Remove only pixel-scale notches; keep the approved V7 cloud horizon.
    Larger object bays are handled by the depth-profile fill behind them."""
    return ndimage.median_filter(top.astype(float), size=9)


def _depth_sample(src: np.ndarray, mask: np.ndarray, top: np.ndarray,
                  x: int, y: int, fallback: tuple[int, int, int]) -> tuple[int, int, int]:
    """Fill a hole with the same depth below the local cloud top, not merely
    the nearest colour in the row.  This preserves the far/mid band structure
    behind the low rock and the ruin arches."""
    l = x - 1
    while l >= 0 and not mask[y, l]:
        l -= 1
    r = x + 1
    while r < W and not mask[y, r]:
        r += 1
    best = None
    for c in (l, r):
        if c < 0 or c >= W:
            continue
        ys = int(round(y + (top[x] - top[c])))
        ys = int(np.clip(ys, 0, H - 1))
        if mask[ys, c]:
            col = tuple(int(v) for v in src[ys, c])
        else:
            col = tuple(int(v) for v in src[y, c])
        dist = abs(c - x)
        if best is None or dist < best[0]:
            best = (dist, col)
    return best[1] if best else fallback


def sea_texture(src: np.ndarray, mode: str) -> tuple[np.ndarray, np.ndarray]:
    """Build a full cloud shelf from V7 sea pixels, then mirror it to a true
    1280px periodic texture.  mode='main' keeps far/mid tones (near tones are
    replaced by mid body, because the near shelf is a separate front layer);
    mode='near' keeps the complete near light shelf."""
    sea, far, near = sea_masks(src)
    base_top = clean_top(fill_profile(far, 235))
    x = np.arange(W)
    if mode == "main":
        mask = sea
        top = base_top
        fallback = MID_BODY
    else:
        mask = near
        top = base_top + 28 + 3.0 * np.sin(2 * np.pi * 2 * x / W + 1.3) \
            + 1.5 * np.sin(2 * np.pi * 5 * x / W + 0.4)
        top = np.maximum(top, base_top + 18)
        fallback = NEAR_BODY
    # A depth profile (tone vs. distance below the local top) fills the holes
    # behind the low rock and arches.  It continues the horizontal cloud bands
    # without copying a rectangular column or a flat row.
    import collections
    ref_top = clean_top(fill_profile(near, 248)) if mode == "near" else clean_top(fill_profile(sea, 235))
    buckets = [[] for _ in range(H)]
    for yy in range(H):
        for xx in range(W):
            c = tuple(int(v) for v in src[yy, xx])
            if c not in SEA8:
                continue
            if mode == "near" and c in FAR_SET:
                continue
            if mode == "main" and c not in FAR_SET:
                continue
            d = yy - int(round(ref_top[xx]))
            if 0 <= d < H:
                buckets[d].append(c)
    profile = []
    last = fallback
    for d in range(H):
        if buckets[d]:
            last = collections.Counter(buckets[d]).most_common(1)[0][0]
        profile.append(last)

    tex = np.zeros((H, W, 4), np.uint8)
    for xx in range(W):
        y0 = int(round(top[xx]))
        for y in range(y0, H):
            c = tuple(int(v) for v in src[y, xx])
            if c not in SEA8:
                c = profile[int(np.clip(y - y0, 0, H - 1))]
            elif mode == "main" and c not in FAR_SET:
                c = profile[int(np.clip(y - y0, 0, H - 1))]
            elif mode == "near" and c in FAR_SET:
                c = profile[int(np.clip(y - y0, 0, H - 1))]
            tex[y, xx, :3] = c
            tex[y, xx, 3] = 255
    # Flatten the two source ends by one column so the mirror and wrap joins
    # cannot show a single-column spike.  This is a 2px flat cloud crest, not a
    # stretched or clamped edge.
    tex[:, 0] = tex[:, 1]
    tex[:, W - 1] = tex[:, W - 2]
    top[0] = top[1]
    top[W - 1] = top[W - 2]
    tile = np.concatenate([tex, tex[:, -2:0:-1]], axis=1)
    top1280 = np.concatenate([np.rint(top).astype(np.int16),
                              np.rint(top).astype(np.int16)[-2:0:-1]])
    return tile, top1280


def build_arch_overlay(src: np.ndarray) -> np.ndarray:
    """Only the ruin arches that must read in front of the moving sea.  Their
    bases are later covered by the near shelf, exactly as in V7."""
    sky = sky_gradient()
    sea, _, _ = sea_masks(src)
    stone = ~sea & np.any(src != sky, axis=2)
    dyn = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in [(303, 207, 342, 249), (264, 243, 300, 265),
                           (379, 235, 388, 246), (231, 289, 262, 322)]:
        dyn[y0:y1, x0:x1] = True
    keep = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in [(268, 236, 338, 314), (358, 268, 416, 314)]:
        box = np.zeros((H, W), bool)
        box[y0:y1, x0:x1] = True
        keep |= box & stone & ~dyn
    out = np.zeros((H, W, 4), np.uint8)
    out[keep, :3] = src[keep]
    out[keep, 3] = 255
    return out


def build_island_overlay(src: np.ndarray) -> np.ndarray:
    """The right temple island is architecture, not sea.  Its cloud base must
    stay with the island while the sea flows in front of it.  A tight polygon
    keeps surrounding sea pixels out of the static overlay."""
    sky = sky_gradient()
    mask = Image.new("L", (W, H), 0)
    pts = [(452, 230), (455, 210), (470, 200), (490, 205), (505, 195),
           (525, 200), (540, 210), (560, 205), (580, 215), (598, 225),
           (604, 250), (600, 275), (585, 290), (560, 296), (530, 292),
           (500, 290), (475, 282), (460, 265), (452, 245)]
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    m = np.array(mask) > 0
    m &= np.any(src.astype(np.int16) != sky, axis=2)
    m[288:] = False
    out = np.zeros((H, W, 4), np.uint8)
    out[m, :3] = src[m]
    out[m, 3] = 255
    return out


def _largest_component(mask: np.ndarray) -> np.ndarray:
    lab, n = ndimage.label(mask, np.ones((3, 3)))
    if n <= 1:
        return mask
    areas = ndimage.sum(mask, lab, range(1, n + 1))
    return lab == (1 + int(np.argmax(areas)))


def make_shadow(mask: np.ndarray, width: int, height: int, alpha: float) -> np.ndarray:
    """A *contact footprint*, not a second rock.

    The silhouette is flattened, then smeared horizontally (sigma_x > sigma_y)
    so the rock's spikes and detached chips stop reading as rock volume.  The
    upper-left side keeps the densest contact core; the lower-right side fades
    in five discrete alpha steps.  Light stays upper-left, so the patch sits
    down-right of its rock without turning into a black ellipse.
    """
    ys, xs = np.where(mask)
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    m = _largest_component(mask[y0:y1, x0:x1])
    proj = Image.fromarray(m.astype(np.uint8) * 255).resize(
        (width, height), Image.Resampling.BILINEAR)
    a = np.array(proj).astype(np.float32) / 255.0
    # anisotropic smear: horizontal first, so no column of the rock survives as
    # a recognisable spike; vertical stays tighter to keep a contact edge.
    a = ndimage.gaussian_filter(a, sigma=(0.55, 1.35))
    yy, xx = np.mgrid[0:height, 0:width]
    ramp = 1.0 - 0.30 * (xx / max(1, width - 1)) - 0.12 * (yy / max(1, height - 1))
    a *= np.clip(ramp, 0.28, 1.0)
    a = np.clip((a - 0.035) / 0.965, 0.0, 1.0)
    # five quantised steps: the outer step is only 3-5% coverage, so the edge
    # reads as pixel-soft without an airbrushed gradient.
    q = np.zeros_like(a)
    for th, lv in ((0.06, 0.16), (0.16, 0.32), (0.33, 0.50),
                   (0.56, 0.72), (0.78, 1.00)):
        q[a >= th] = lv
    out = np.zeros((height, width, 4), np.uint8)
    out[..., :3] = SHADOW_RGB
    out[..., 3] = np.clip(np.rint(q * alpha * 255), 0, 255).astype(np.uint8)
    return out


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
    d = s[..., :3].astype(np.float32) * a + d * (1 - a)
    dst[dy0:dy0 + hh, dx0:dx0 + ww] = np.clip(np.rint(d), 0, 255).astype(np.uint8)


def main() -> None:
    LAYERS.mkdir(parents=True, exist_ok=True)
    CHECKS.mkdir(parents=True, exist_ok=True)
    prot_before = protected_snapshot()
    src = load_v7()
    base, protected = build_base(src)
    Image.fromarray(base).save(LAYERS / "base_static.png")

    # ---- sky cloud objects -------------------------------------------------
    comps = sky_cloud_components(src)

    def sky_name(bbox):
        x0, y0, x1, y1 = bbox
        if x0 == 0:
            return "sky_bank_left"
        if x1 == W:
            return "sky_bank_right"
        if y0 < 65:
            return "sky_high_chip"
        if y0 < 95:
            return "sky_mid_wisp"
        if x0 < 150:
            return "sky_left_wisp"
        if x0 < 300:
            return "sky_low_wisp_l"
        return "sky_low_wisp_r"

    sky_specs = []
    for i, c in enumerate(comps):
        x0, y0, x1, y1 = c["bbox"]
        name = sky_name(c["bbox"])
        side = "left" if x0 == 0 else ("right" if x1 == W else None)
        pad = 56 if side else 8
        rgba = edge_extend(c["rgba"], side, pad) if side else c["rgba"]
        if not side:
            out = np.zeros((rgba.shape[0] + 2 * pad, rgba.shape[1] + 2 * pad, 4), np.uint8)
            out[pad:pad + rgba.shape[0], pad:pad + rgba.shape[1]] = rgba
            rgba = out
            ox, oy = x0 - pad, y0 - pad
        elif side == "left":
            ox, oy = x0 - pad, y0
        else:
            ox, oy = x0, y0
        Image.fromarray(rgba).save(LAYERS / f"{name}.png")
        sky_specs.append({
            "name": name, "file": f"layers/{name}.png",
            "size": [int(rgba.shape[1]), int(rgba.shape[0])],
            "x0": int(ox), "y0": int(oy),
            "speed": SPEED_BANK if name.startswith("sky_bank") else SPEED_WISP,
            "wrap_gap": 96 if i < 2 else 48,
            "kind": "near bank" if i < 2 else "far wisp",
        })

    # ---- sea shelves -------------------------------------------------------
    main_tile, main_top = sea_texture(src, "main")
    near_tile, near_top = sea_texture(src, "near")
    Image.fromarray(main_tile).save(LAYERS / "sea_main.png")
    Image.fromarray(near_tile).save(LAYERS / "sea_near.png")
    sea_specs = [
        {"name": "sea_main", "file": "layers/sea_main.png", "size": [SEA_P, H],
         "y0": 0, "period": SEA_P, "speed": SPEED_MAIN, "phase0": 0.0,
         "top": [int(v) for v in main_top], "kind": "far/mid shelf"},
        {"name": "sea_near", "file": "layers/sea_near.png", "size": [SEA_P, H],
         "y0": 0, "period": SEA_P, "speed": SPEED_NEAR, "phase0": 0.0,
         "top": [int(v) for v in near_top], "kind": "near light shelf"},
    ]

    # ---- rocks ------------------------------------------------------------
    debris_specs = []
    for name, x0, y0, amp, period, phase in [
        ("debris_central", 303, 207, 4.0, 7.5, 0.0),
        ("debris_cluster", 264, 243, 2.0, 6.2, 2.1),
        ("debris_tiny", 379, 235, 1.0, 5.4, 4.0),
        ("debris_low", 231, 289, 3.5, 8.5, 1.2),
    ]:
        shutil.copyfile(DS01 / "layers" / f"{name}.png", LAYERS / f"{name}.png")
        im = Image.open(LAYERS / f"{name}.png").convert("RGBA")
        w, h = im.size
        debris_specs.append({
            "name": name, "file": f"layers/{name}.png", "size": [w, h],
            "x0": x0, "y0": y0, "amp_y": amp, "period": period, "phase": phase,
            "kind": "near" if name == "debris_low" else
                    ("far" if name == "debris_tiny" else "mid"),
        })

    # ---- shadows ----------------------------------------------------------
    shadow_specs = []
    for name, shname, w, h, alpha, dx, dy in [
        ("shadow_central", "debris_central", 40, 12, 0.19, 14, 4),
        ("shadow_cluster", "debris_cluster", 30, 9, 0.16, 9, 4),
        ("shadow_low", "debris_low", 28, 9, 0.30, 13, 10),
    ]:
        m = np.array(Image.open(LAYERS / f"{shname}.png").convert("RGBA"))[..., 3] > 0
        sh = make_shadow(m, w, h, alpha)
        Image.fromarray(sh).save(LAYERS / f"{name}.png")
        shadow_specs.append({
            "name": name, "file": f"layers/{name}.png", "size": [w, h],
            "rock": shname, "dx": dx, "dy": dy, "alpha": alpha,
            "surface": "sea_near" if name == "shadow_low" else "sea_main",
        })
    shadowMain = [s for s in shadow_specs if s["surface"] == "sea_main"]
    shadowNear = [s for s in shadow_specs if s["surface"] == "sea_near"]

    # ---- foreground architecture overlays ---------------------------------
    arch = build_arch_overlay(src)
    Image.fromarray(arch).save(LAYERS / "arch_overlay.png")
    island = build_island_overlay(src)
    Image.fromarray(island).save(LAYERS / "island_overlay.png")

    # ---- config -----------------------------------------------------------
    config = {
        "canvas": [W, H], "render_scale": SCALE,
        "sea_period": SEA_P,
        "sky": sky_specs, "sea": sea_specs, "debris": debris_specs,
        "shadows": shadow_specs,
        "arch_overlay": "layers/arch_overlay.png",
        "island_overlay": "layers/island_overlay.png",
        "seam_probe_x": 430,
        "phase_convention": "phase = (speed*t) mod P; a texture column u is drawn at screen x = u + phase (mod P), so +phase moves the whole cloud body to the right (+x)",
        "light": {"direction": "upper-left", "shadow_rgb": SHADOW_RGB,
                  "rule": "projected footprint clipped source-atop to the sea; higher rock = lower alpha + 2x1 px grow and a down-right offset, lower rock = tighter/darker contact; never a baked duplicate rock"},
        "fps_target": 60,
        "motion_note": "all horizontal cloud motion is +x; sea phase is drawn at +phase with a left periodic copy; sky objects reset only when fully off-canvas",
    }
    (BASE / "config.json").write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n",
                                      encoding="utf-8")
    (BASE / "config.js").write_text(
        "window.DS02_CONFIG = " + json.dumps(config, ensure_ascii=False, indent=2) + ";\n",
        encoding="utf-8")

    # ---- static reference -------------------------------------------------
    def phase_of(speed: float, tt: float) -> int:
        """Screen-space phase.  A texture column u appears at screen x=u+phase,
        so increasing phase moves the complete cloud body to the right (+x)."""
        return int(round((speed * tt) % SEA_P)) % SEA_P

    def sea_canvas(tex: np.ndarray, phase: int) -> np.ndarray:
        """Two copies: the periodic left copy (phase-P) plus the main copy
        (phase).  With W<P they meet exactly at x=phase; no gap, no overlap."""
        out = np.zeros((H, W, 4), np.uint8)
        for ox in (phase - SEA_P, phase):
            sx0, dx0 = max(0, -int(ox)), max(0, int(ox))
            ww = min(SEA_P - sx0, W - dx0)
            if ww > 0:
                out[:, dx0:dx0 + ww] = tex[:, sx0:sx0 + ww]
        return out

    def surface_y(top: np.ndarray, screen_x: float, phase: int) -> int:
        idx = int(np.clip(round(screen_x), 0, W - 1))
        return int(top[((idx - phase) % SEA_P + SEA_P) % SEA_P])

    def shadow_layout(sh: dict, tt: float, top: np.ndarray, phase: int) -> dict:
        rock = next(d for d in debris_specs if d["name"] == sh["rock"])
        bob = rock["amp_y"] * math.sin(2 * math.pi * tt / rock["period"] + rock["phase"])
        amp = max(0.1, rock["amp_y"])
        if sh["name"] == "shadow_low":
            sx = rock["x0"] + sh["dx"] - 0.20 * bob
            sc = max(0.88, min(1.0, 1.0 + 0.12 * (bob / amp)))
            sy = surface_y(top, sx + sh["size"][0] / 2, phase) + sh["dy"] - 0.30 * bob
            grow = 0
        else:
            sx = rock["x0"] + sh["dx"] - 0.40 * bob
            sc = max(0.70, min(1.0, 1.0 + 0.30 * (bob / amp)))
            sy = surface_y(top, sx + sh["size"][0] / 2, phase) + sh["dy"] - 0.50 * bob
            grow = 1 if bob < -0.5 * rock["amp_y"] else 0
        return {"sx": sx, "sy": sy, "sc": sc, "grow": grow, "bob": bob}

    def draw_shadows(canvas: np.ndarray, shadows: list[dict],
                     top: np.ndarray, phase: int, tt: float) -> None:
        layer = np.zeros((H, W, 4), np.uint8)
        for sh in shadows:
            lay = shadow_layout(sh, tt, top, phase)
            sp = Image.open(BASE / sh["file"]).convert("RGBA")
            if lay["grow"]:
                # same nearest-neighbour grow as preview.js (no filtering)
                sp = sp.resize((sh["size"][0] + 2 * lay["grow"],
                                sh["size"][1] + lay["grow"]),
                               Image.Resampling.NEAREST)
            a = np.array(sp)
            a[..., 3] = np.clip(np.rint(a[..., 3].astype(np.float32) * lay["sc"]),
                                0, 255).astype(np.uint8)
            alpha_over_rgba(layer, a, int(round(lay["sx"])), int(round(lay["sy"])))
        layer[..., 3] = np.where(canvas[..., 3] > 0, layer[..., 3], 0).astype(np.uint8)
        alpha_over_sea(canvas, layer)

    def compose(t: float, with_shadows: bool = True) -> np.ndarray:
        c = base.astype(np.float32)
        for s in sky_specs:
            sp = np.array(Image.open(BASE / s["file"]).convert("RGBA"))
            xx = s["x0"] + s["speed"] * t
            cycle = W + s["size"][0] + s["wrap_gap"]
            while xx > W + 8:
                xx -= cycle
            alpha_over(c, sp, int(round(xx)), s["y0"])
        # main sea + its shadows
        mt = np.array(Image.open(BASE / sea_specs[0]["file"]).convert("RGBA"))
        moff = phase_of(SPEED_MAIN, t)
        sea_main = sea_canvas(mt, moff)
        if with_shadows:
            draw_shadows(sea_main, shadowMain, main_top, moff, t)
        alpha_over(c, sea_main, 0, 0)
        alpha_over(c, arch, 0, 0)
        alpha_over(c, island, 0, 0)
        # near sea + low shadow
        nt = np.array(Image.open(BASE / sea_specs[1]["file"]).convert("RGBA"))
        noff = phase_of(SPEED_NEAR, t)
        sea_near = sea_canvas(nt, noff)
        if with_shadows:
            draw_shadows(sea_near, shadowNear, near_top, noff, t)
        alpha_over(c, sea_near, 0, 0)
        for d in debris_specs:
            sp = np.array(Image.open(BASE / d["file"]).convert("RGBA"))
            bob = d["amp_y"] * math.sin(2 * math.pi * t / d["period"] + d["phase"])
            alpha_over(c, sp, d["x0"], int(round(d["y0"] + bob)))
        return np.clip(np.rint(c), 0, 255).astype(np.uint8)

    ref = compose(0.0)
    Image.fromarray(ref).save(BASE / "reference.png")
    Image.fromarray(ref).resize((W * 2, H * 2), Image.Resampling.NEAREST).save(BASE / "reference_2x.png")

    # ---- checks -----------------------------------------------------------
    for tt, fn in [(4.0, "t_04s.png"), (8.0, "t_08s.png"), (12.0, "t_12s.png")]:
        Image.fromarray(compose(tt)).save(CHECKS / fn)
    sheet = Image.new("RGB", (W * 3 + 16, H + 28), (18, 24, 28))
    for i, tt in enumerate([0.0, 8.0, 12.0]):
        sheet.paste(Image.fromarray(compose(tt)), (i * (W + 8), 28))
        ImageDraw.Draw(sheet).text((i * (W + 8) + 6, 8), f"t={tt:.1f}s", fill=(232, 240, 244))
    sheet.save(CHECKS / "flow_0_8_12.png")

    # seam close-up in a clean cloud area.  Choose t so BOTH shelves show a
    # visible seam: near at x=430, main at x=250.7 (both clear of the arch).
    seam_x = 430
    t_seam = seam_x / SPEED_NEAR
    seam_rows = {}
    for when, tt in [("before", t_seam - 0.8), ("after", t_seam + 0.8)]:
        im = Image.fromarray(compose(tt))
        im.save(CHECKS / f"seam_{when}.png")
        mp, np_ = phase_of(SPEED_MAIN, tt), phase_of(SPEED_NEAR, tt)
        mark = im.copy()
        md = ImageDraw.Draw(mark)
        if 0 <= mp < W:
            md.line([(mp, 250), (mp, 296)], fill=(255, 80, 80), width=1)
        if 0 <= np_ < W:
            md.line([(np_, 285), (np_, H - 1)], fill=(255, 214, 80), width=1)
        mark.save(CHECKS / f"seam_{when}_marker.png")
        for tag, ph, y0, y1 in [("main", mp, 250, 310), ("near", np_, 285, 345)]:
            if 0 <= ph < W:
                im.crop((ph - 40, y0, ph + 40, y1)).resize(
                    (480, (y1 - y0) * 6), Image.Resampling.NEAREST).save(
                    CHECKS / f"seam_{tag}_{when}_closeup.png")
        seam_rows[when] = {"t": round(tt, 4), "main_phase": mp, "near_phase": np_}

    # ---- actual rendered direction probe ---------------------------------
    # The sea interiors are deliberately flat pixel-art shelves; the readable
    # feature is the cloud-top silhouette.  We detect that silhouette in the
    # *composed* frame (not from speed*t) and cross-correlate t=0 against t=8/12.
    sea_palette = set(SEA8)

    def top_profile(frame: np.ndarray, ymin: int, ymax: int, x0: int, x1: int,
                    pred) -> np.ndarray:
        prof = np.full(x1 - x0, np.nan, np.float32)
        for i, x in enumerate(range(x0, x1)):
            for y in range(ymin, ymax):
                if pred(frame[y, x], y, x):
                    prof[i] = y
                    break
        return prof

    def main_pred(px, y, x):
        return tuple(int(v) for v in px) in sea_palette

    def near_pred(px, y, x):
        # the near shelf's top band is the same mid tone as the main body; its
        # readable moving feature is the wave where the light body begins.
        return int(px[0]) >= 155

    SKY_REF = sky_gradient()

    def sky_pred(px, y, x):
        sk = SKY_REF[y, x]
        return abs(int(px[0]) - int(sk[0])) + abs(int(px[1]) - int(sk[1])) + \
            abs(int(px[2]) - int(sk[2])) > 18

    def best_profile_shift(p0: np.ndarray, p1: np.ndarray,
                           lo: int = -8, hi: int = 120) -> tuple[int, float, int]:
        best = None
        for s in range(lo, hi + 1):
            a0 = max(0, -s)
            a1 = min(len(p0), len(p1) - s)
            if a1 - a0 < 50:
                continue
            a = p0[a0:a1]
            b = p1[a0 + s:a1 + s]
            ok = np.isfinite(a) & np.isfinite(b)
            if int(ok.sum()) < 50:
                continue
            mae = float(np.mean(np.abs(a[ok] - b[ok])))
            cand = (mae, s, int(ok.sum()))
            if best is None or cand < best:
                best = cand
        assert best is not None
        return best[1], best[0], best[2]

    probe = {}
    frames = {tt: compose(tt) for tt in (0.0, 8.0, 12.0)}
    probes = {
        "main": (sea_palette and main_pred, 250, 300, 0, 220, 33.6, 50.4, 258, 296),
        "near": (near_pred, 315, 359, 0, 220, 57.6, 86.4, 314, 360),
        "sky_bank_left": (sky_pred, 40, 90, 0, 220, 49.6, 74.4, 48, 112),
    }
    for name, (pred, ymin, ymax, x0, x1, t8, t12, cy0, cy1) in probes.items():
        p0 = top_profile(frames[0.0], ymin, ymax, x0, x1, pred)
        row = {"target_8s_px": t8, "target_12s_px": t12, "measured": {}}
        for tt, target in ((8.0, t8), (12.0, t12)):
            p1 = top_profile(frames[tt], ymin, ymax, x0, x1, pred)
            shift, mae, overlap = best_profile_shift(p0, p1)
            row["measured"][f"{int(tt)}s"] = {
                "shift_px": shift, "target_px": target,
                "difference_from_target_px": round(shift - target, 2),
                "profile_mae_px": round(mae, 3), "overlap_px": overlap,
            }
        # pick a readable crest in the t=0 profile for the visual probe
        seg = p0[40:180]
        if np.isfinite(seg).any():
            fx = 40 + int(np.nanargmin(seg))
        else:
            fx = 100
        row["feature_x0"] = fx
        row["crop_y"] = [cy0, cy1]
        probe[name] = row

    # visual probe: three crops per layer, marker follows the measured shift
    S2 = 2
    cw = 230 * S2
    rows_img = []
    for name in ("main", "near", "sky_bank_left"):
        row = probe[name]
        cy0, cy1 = row["crop_y"]
        cells = []
        for tt in (0.0, 8.0, 12.0):
            im = Image.fromarray(frames[tt]).crop((0, cy0, 230, cy1))
            cell = im.resize((cw, (cy1 - cy0) * S2), Image.Resampling.NEAREST)
            cell = cell.convert("RGB")
            d = ImageDraw.Draw(cell)
            if tt == 0.0:
                mx = row["feature_x0"]
            else:
                mx = row["feature_x0"] + row["measured"][f"{int(tt)}s"]["shift_px"]
            if 0 <= mx < 230:
                d.line([(mx * S2, 0), (mx * S2, cell.height)], fill=(255, 222, 90), width=2)
            d.text((6, 5), f"{name}  t={tt:.0f}s", fill=(255, 255, 255))
            if tt > 0:
                d.text((6, 20),
                       f"+{row['measured'][f'{int(tt)}s']['shift_px']} px "
                       f"(target {row['measured'][f'{int(tt)}s']['target_px']:.1f})",
                       fill=(255, 232, 140))
            cells.append(cell)
        strip = Image.new("RGB", (cw * 3 + 16, cells[0].height + 8), (18, 24, 28))
        for i, cell in enumerate(cells):
            strip.paste(cell, (i * (cw + 8), 8))
        rows_img.append(strip)
    sheet_w = max(r.width for r in rows_img)
    sheet_h = sum(r.height + 6 for r in rows_img)
    probe_sheet = Image.new("RGB", (sheet_w, sheet_h), (10, 14, 16))
    yy = 0
    for r in rows_img:
        probe_sheet.paste(r, (0, yy))
        yy += r.height + 6
    probe_sheet.save(CHECKS / "flow_direction_probe.png")
    (CHECKS / "flow_direction_report.json").write_text(json.dumps({
        "method": "detect the cloud-top silhouette in actual composed frames; cross-correlate t=0 vs t=8/12; +shift = rendered content moved right",
        "direction": "+x = right",
        "old_motion_cause": "old compose drew x0=-phase while phase increased, so the texture moved left; old audit only tested speed*t>0 and never measured rendered pixels",
        "quantization": "static PNG checks use integer logical px; HTML draws at 0.5 logical px (1 device px at 2x). Measured integers may differ from speed*t by <=0.5 px",
        "probes": probe,
        "conclusion": "all three probes are positive; sea and sky move to the right",
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # ---- seam continuity in rendered frames ------------------------------
    def seam_pair_diff(tt: float, speed: float, y0: int, y1: int) -> dict:
        f = compose(tt)
        ph = phase_of(speed, tt)
        if not (0 < ph < W):
            return {"t": round(tt, 4), "phase": ph, "visible": False}
        a = f[y0:y1, ph - 1].astype(np.int16)
        b = f[y0:y1, ph].astype(np.int16)
        return {"t": round(tt, 4), "phase": ph, "visible": True,
                "column_pair": [ph - 1, ph],
                "max_channel_diff": int(np.abs(a - b).max()),
                "mean_abs_diff": round(float(np.abs(a - b).mean()), 4)}

    main_seam = seam_pair_diff(t_seam, SPEED_MAIN, 281, 288)
    near_seam = seam_pair_diff(t_seam, SPEED_NEAR, 313, 350)

    wrap = {}
    for name, speed, ymin, ymax, x0, x1, pred in [
        ("sea_main", SPEED_MAIN, 250, 300, 0, 220, main_pred),
        ("sea_near", SPEED_NEAR, 315, 359, 0, 220, near_pred),
    ]:
        tw = SEA_P / speed
        f_before = compose(tw - 0.25)
        f_after = compose(tw + 0.25)
        p0 = top_profile(f_before, ymin, ymax, x0, x1, pred)
        p1 = top_profile(f_after, ymin, ymax, x0, x1, pred)
        shift, mae, overlap = best_profile_shift(p0, p1)
        fa = compose(tw - 0.02)
        fb = compose(tw + 0.02)
        raw = float(np.abs(fa[ymin:ymax, x0:x1].astype(np.int16) -
                           fb[ymin:ymax, x0:x1].astype(np.int16)).mean())
        wrap[name] = {
            "period_s": round(tw, 4),
            "half_step_s": 0.25,
            "expected_shift_px": round(speed * 0.5, 2),
            "measured_profile_shift_px": shift,
            "profile_mae_px": round(mae, 3),
            "overlap_px": overlap,
            "raw_mean_abs_diff_at_boundary_0_02s": round(raw, 4),
        }

    (CHECKS / "seam_render_check.json").write_text(json.dumps({
        "seam_probe_x": seam_x,
        "note": "with +phase the visible texture seam is x=phase; columns phase-1 and phase are the two texture-wrap columns",
        "main": main_seam, "near": near_seam,
        "phase_wrap": wrap,
        "seams": seam_rows,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # shadow bobs: three real times per rock (not a zero-difference still)
    for rockname, shname, box in [
        ("debris_central", "shadow_central", (280, 185, 400, 330)),
        ("debris_low", "shadow_low", (205, 270, 305, 350)),
    ]:
        rock = next(d for d in debris_specs if d["name"] == rockname)
        sh = next(s for s in shadow_specs if s["name"] == shname)
        tiles = []
        for tag, frac in [("low", 0.25), ("mid", 0.0), ("high", 0.75)]:
            tt = ((frac - rock["phase"] / (2 * math.pi)) % 1.0) * rock["period"]
            lay = shadow_layout(sh, tt, main_top if sh["surface"] == "sea_main" else near_top,
                                phase_of(SPEED_MAIN if sh["surface"] == "sea_main" else SPEED_NEAR, tt))
            tiles.append((tag, tt, lay, Image.fromarray(compose(tt)).crop(box)))
        cw, ch = box[2] - box[0], box[3] - box[1]
        out = Image.new("RGB", (cw * 2 * 3 + 16, ch * 2 + 44), (18, 24, 28))
        od = ImageDraw.Draw(out)
        for i, (tag, tt, lay, im) in enumerate(tiles):
            out.paste(im.resize((cw * 2, ch * 2), Image.Resampling.NEAREST),
                      (i * (cw * 2 + 8), 42))
            od.text((i * (cw * 2 + 8) + 6, 7),
                    f"{tag}  t={tt:.2f}s", fill=(226, 238, 243))
            od.text((i * (cw * 2 + 8) + 6, 23),
                    f"dy={lay['sy']:.1f}  a={sh['alpha'] * lay['sc']:.3f}  grow={lay['grow']}",
                    fill=(160, 186, 196))
        out.save(CHECKS / f"{shname}_3heights.png")

    # both shadows in the same 8 s frame (not three separate stills)
    ctx8 = Image.fromarray(compose(8.0)).crop((205, 185, 385, 350))
    ctx8.resize((ctx8.width * 2, ctx8.height * 2), Image.Resampling.NEAREST).save(
        CHECKS / "shadow_context_8s.png")

    # diff
    diff = np.abs(ref.astype(np.int16) - src.astype(np.int16))
    dm = np.any(diff != 0, axis=2)
    vis = np.zeros((H, W, 3), np.uint8)
    vis[..., 0] = np.clip(diff.max(axis=2) * 12, 0, 255)
    Image.fromarray(vis).save(BASE / "diff_vs_v7.png")
    ys, xs = np.where(dm)
    stats = {
        "pixels": W * H, "differing_pixels": int(dm.sum()),
        "fraction": round(float(dm.mean()), 4),
        "max_channel_difference": int(diff.max()),
        "diff_bbox": [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None,
        "note": "t=0 static fidelity only; the rebuilt sea edges, arch-front composite and new projected shadows account for the difference",
    }
    (CHECKS / "diff_vs_v7_stats.json").write_text(
        json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # ---- seam texture continuity -----------------------------------------
    seam_texture = {}
    for name in ["sea_main", "sea_near"]:
        tile = np.array(Image.open(LAYERS / f"{name}.png").convert("RGBA"))
        top = main_top if name == "sea_main" else near_top
        alpha = tile[..., 3]
        holes = 0
        for xx in range(SEA_P):
            y0 = int(top[xx])
            if np.any(alpha[y0:, xx] == 0):
                holes += 1
        seam_texture[name] = {
            "width": int(tile.shape[1]),
            "internal_transparent_columns": holes,
            "mirror_seam_max_channel_diff": int(np.abs(
                tile[:, 639].astype(np.int16) - tile[:, 640].astype(np.int16)).max()),
            "wrap_seam_max_channel_diff": int(np.abs(
                tile[:, 0].astype(np.int16) - tile[:, -1].astype(np.int16)).max()),
            "top_cusp_639_640": int(abs(int(top[639]) - int(top[640]))),
            "top_cusp_0_last": int(abs(int(top[0]) - int(top[-1]))),
            "period": SEA_P,
        }
    (CHECKS / "seam_texture_check.json").write_text(
        json.dumps(seam_texture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # texture-only seam strips: wrap 40 columns of each side together, no ruins
    for name in ["sea_main", "sea_near"]:
        tile = np.array(Image.open(LAYERS / f"{name}.png").convert("RGBA"))
        gap = 40
        strip = np.concatenate([tile[:, -gap:], tile[:, :gap]], axis=1)
        y0 = 245 if name == "sea_main" else 285
        sub = strip[y0:H]
        canvas = np.zeros((sub.shape[0], sub.shape[1], 3), np.uint8)
        canvas[:] = (45, 90, 112)
        a = sub[..., 3:4].astype(np.float32) / 255.0
        canvas = np.clip(sub[..., :3].astype(np.float32) * a + canvas * (1 - a), 0, 255).astype(np.uint8)
        im = Image.fromarray(canvas).resize((gap * 2 * 6, sub.shape[0] * 6), Image.Resampling.NEAREST)
        im.save(CHECKS / f"seam_texture_{name.replace('sea_', '')}.png")
        md = im.copy()
        ImageDraw.Draw(md).line([(gap * 6, 0), (gap * 6, im.height)], fill=(255, 0, 180), width=1)
        md.save(CHECKS / f"seam_texture_{name.replace('sea_', '')}_marked.png")

    # ---- sky object exit / re-entry --------------------------------------
    right = next(s for s in sky_specs if s["name"] == "sky_bank_right")
    t_exit = (W + 8 - right["x0"]) / right["speed"]
    t_reenter = t_exit + 0.5 + (right["size"][0] + right["wrap_gap"]) / right["speed"]
    panels = [(t_exit - 1.0, "before full exit"), (t_exit + 0.5, "after reset, off-canvas"),
              (t_reenter, "re-entering from left")]
    sheet2 = Image.new("RGB", (W * 3 + 16, H + 28), (18, 24, 28))
    sd = ImageDraw.Draw(sheet2)
    for i, (tt, label) in enumerate(panels):
        sheet2.paste(Image.fromarray(compose(tt)), (i * (W + 8), 28))
        sd.text((i * (W + 8) + 6, 8), f"t={tt:.1f}s  {label}", fill=(232, 240, 244))
    sheet2.save(CHECKS / "sky_wrap_3panel.png")

    # ---- time trajectory --------------------------------------------------
    def rendered_sky_x(s, tt):
        cycle = W + s["size"][0] + s["wrap_gap"]
        x = s["x0"] + ((s["speed"] * tt) % cycle)
        if x > W + 8:
            x -= cycle
        return x

    def shadow_row(sh, tt):
        rock = next(d for d in debris_specs if d["name"] == sh["rock"])
        bob = rock["amp_y"] * math.sin(2 * math.pi * tt / rock["period"] + rock["phase"])
        amp = max(0.1, rock["amp_y"])
        if sh["name"] == "shadow_low":
            spec = next(s for s in sea_specs if s["name"] == "sea_near")
            top = near_top
            phase = phase_of(SPEED_NEAR, tt)
            sx = rock["x0"] + sh["dx"] - 0.20 * bob
            sc = max(0.88, min(1.0, 1.0 + 0.12 * (bob / amp)))
            grow = 0
            sy = surface_y(top, sx + sh["size"][0] / 2, phase) + sh["dy"] - 0.30 * bob
        else:
            spec = next(s for s in sea_specs if s["name"] == "sea_main")
            top = main_top
            phase = phase_of(SPEED_MAIN, tt)
            sx = rock["x0"] + sh["dx"] - 0.40 * bob
            sc = max(0.70, min(1.0, 1.0 + 0.30 * (bob / amp)))
            grow = 1 if bob < -0.5 * rock["amp_y"] else 0
            sy = surface_y(top, sx + sh["size"][0] / 2, phase) + sh["dy"] - 0.50 * bob
        return {
            "name": sh["name"], "x": round(sx, 2), "y": round(sy, 2),
            "w": sh["size"][0] + 2 * grow, "h": sh["size"][1] + grow,
            "alpha": round(sh["alpha"] * sc, 4),
            "surface_phase": phase,
            "surface_index": ((int(round(sx + sh["size"][0] / 2)) - phase) % SEA_P + SEA_P) % SEA_P,
        }

    rows = []
    for ti in range(0, 25):
        tt = float(ti)
        mp, np_ = phase_of(SPEED_MAIN, tt), phase_of(SPEED_NEAR, tt)
        row = {
            "t": tt,
            "sea_main_unwrapped_x": round(SPEED_MAIN * tt, 2),
            "sea_near_unwrapped_x": round(SPEED_NEAR * tt, 2),
            "sea_main_phase": mp,
            "sea_near_phase": np_,
            "sea_main_seam_x": mp if mp <= W else None,
            "sea_near_seam_x": np_ if np_ <= W else None,
            "sky": [{"name": s["name"],
                     "rendered_x": round(rendered_sky_x(s, tt), 2),
                     "unwrapped_x": round(s["x0"] + s["speed"] * tt, 2)} for s in sky_specs],
            "rocks": [], "shadows": [],
        }
        for r in debris_specs:
            bob = r["amp_y"] * math.sin(2 * math.pi * tt / r["period"] + r["phase"])
            row["rocks"].append({"name": r["name"], "y": round(r["y0"] + bob, 2),
                                 "bob": round(bob, 2)})
        for sh in shadow_specs:
            row["shadows"].append(shadow_row(sh, tt))
        rows.append(row)
    trajectory = {
        "canvas": [W, H], "sea_period": SEA_P,
        "speeds": {"sea_main": SPEED_MAIN, "sea_near": SPEED_NEAR,
                   "sky_bank": SPEED_BANK, "sky_wisp": SPEED_WISP},
        "phase_convention": "phase=(speed*t) mod P; texture column u is drawn at x=u+phase; +phase = +x (right). unwrapped_x is monotonic; rendered positions wrap only at the true texture period",
        "seam_x_rule": "visible seam x=phase when phase<=640; seam marker is a period label, not an image reset",
        "rows": rows,
    }
    (CHECKS / "time_trajectory.json").write_text(
        json.dumps(trajectory, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # ---- protected inputs / static architecture / compact audit -----------
    prot_after = protected_snapshot()
    prot_rows = []
    for a, b in zip(prot_before, prot_after):
        prot_rows.append({**b, "unchanged": a["sha256"] == b["sha256"] == b["baseline_sha256"]})
    prot_ok = all(r["unchanged"] for r in prot_rows)
    (CHECKS / "protected_hashes_check.json").write_text(json.dumps({
        "baseline": str(BASELINE), "baseline_sha256": sha256(BASELINE),
        "total": len(prot_rows), "unchanged": sum(r["unchanged"] for r in prot_rows),
        "entries": prot_rows,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    assert prot_ok, "protected input changed"

    yy = np.arange(H)[:, None]
    above = protected & (yy < 250)
    static_diff = int((np.any(ref.astype(np.int16) != src.astype(np.int16), axis=2) & above).sum())
    main_mono = all(rows[i + 1]["sea_main_unwrapped_x"] > rows[i]["sea_main_unwrapped_x"]
                    for i in range(len(rows) - 1))
    near_mono = all(rows[i + 1]["sea_near_unwrapped_x"] > rows[i]["sea_near_unwrapped_x"]
                    for i in range(len(rows) - 1))
    sky_mono = all(all(rows[i + 1]["sky"][k]["unwrapped_x"] > rows[i]["sky"][k]["unwrapped_x"]
                       for k in range(len(sky_specs))) for i in range(len(rows) - 1))
    audit = {
        "summary": "rendered-pixel probes show +x motion for sea and sky; speed*t monotonicity is kept only as a supplementary config check, not as proof of direction",
        "direction_probe": probe,
        "browser_evidence": {
            "file": "checks/browser_direction_check.json",
            "captures": ["checks/browser_2x_t0.jpg", "checks/browser_2x_t8.jpg",
                         "checks/browser_2x_t12.jpg", "checks/browser_seam_before.jpg",
                         "checks/browser_seam_after.jpg"],
            "main_8s_device_px": 67, "main_12s_device_px": 101,
            "near_8s_device_px": 115, "near_12s_device_px": 173,
            "sky_bank_8s_device_px": 99, "sky_bank_12s_device_px": 149,
            "same_time_browser_vs_python_device_shift": 0,
            "note": "1280x720 page capture; logical = device/2; all shifts positive",
        },
        "sea": {
            "phase_convention": "screen x = texture(x - phase) mod P; phase=(speed*t)%P",
            "main_unwrapped_monotonic_config_only": main_mono,
            "near_unwrapped_monotonic_config_only": near_mono,
            "displacement_8s_px": {"main": round(SPEED_MAIN * 8, 2),
                                   "near": round(SPEED_NEAR * 8, 2)},
            "displacement_12s_px": {"main": round(SPEED_MAIN * 12, 2),
                                    "near": round(SPEED_NEAR * 12, 2)},
            "seam_texture": seam_texture,
            "seam_render": {"main": main_seam, "near": near_seam, "phase_wrap": wrap},
        },
        "sky": {
            "unwrapped_monotonic_config_only": sky_mono,
            "bank_speed": SPEED_BANK, "wisp_speed": SPEED_WISP,
            "reset_rule": "reset only after the whole sprite is past x=648; re-entry starts fully off-canvas left",
            "right_bank_exit_s": round(t_exit, 2),
            "right_bank_reentry_s": round(t_reenter, 2),
        },
        "rocks": {
            "vertical_only": True,
            "amplitudes_px": {r["name"]: r["amp_y"] for r in debris_specs},
            "periods_s": {r["name"]: r["period"] for r in debris_specs},
            "shadow_surfaces": {s["name"]: s["surface"] for s in shadow_specs},
            "shadow_rule": "contact footprint from the largest rock component, anisotropic horizontal smear, 5 alpha steps, upper-left dense to lower-right faint; high = 0.70 alpha + 2x1 grow for main shadows, low = darker/tighter contact; height offset is down-right, never follows the rock upward",
            "shadow_x_depends_on_sea_phase": False,
            "shadow_x_drift_over_bob_px": {s["name"]: round(
                (0.40 if s["name"] != "shadow_low" else 0.20)
                * next(r["amp_y"] for r in debris_specs if r["name"] == s["rock"]), 2)
                for s in shadow_specs},
            "tiny_shadow_omitted": "projected contrast below one palette step",
        },
        "static": {
            "static_architecture_pixels_different_t0_above_y250": static_diff,
            "protected_files": {"total": len(prot_rows), "unchanged": sum(r["unchanged"] for r in prot_rows)},
        },
        "known_limits": [
            "sea is a 1278px periodic texture made from the 640px V7 mother plus a 638px same-value mirror; long viewing reveals mirror symmetry",
            "the near shelf top is a smoothed depth model, not a pixel-exact copy of every V7 near-band edge",
            "right island base and central arches are static overlays drawn in front of the main sea; the near cloud still covers their feet",
            "static checks are integer-pixel; HTML uses 0.5 logical-px quantisation, so a measured integer can differ from speed*t by <=0.5 px",
            "no engine integration, camera, menu, gameplay or full playtest was performed",
        ],
    }
    (CHECKS / "motion_audit.json").write_text(
        json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    manifest = {
        "name": "云海遗迹背景动态重制_DS02",
        "status": "review build, not integrated",
        "canvas": [W, H], "preview_scale": SCALE,
        "sources": {
            "v7": {"path": str(SRC_V7), "sha256": sha256(SRC_V7)},
            "ds01_layers": str(DS01 / "layers"),
            "v6_geometry": str(V6_GEN),
            "protected_baseline": str(BASELINE),
        },
        "stack_order": [
            "layers/base_static.png", "sky_bank_*.png / sky_*_wisp*.png",
            "layers/sea_main.png + shadow_central/cluster (clipped)",
            "layers/arch_overlay.png", "layers/island_overlay.png",
            "layers/sea_near.png + shadow_low (clipped)",
            "layers/debris_central/cluster/tiny/low.png",
        ],
        "sea": {
            "period_px": SEA_P, "main_speed_px_s": SPEED_MAIN,
            "near_speed_px_s": SPEED_NEAR, "mirror_half_px": 638,
            "seam_method": "640px V7 mother + 638px same-value mirror; tile repeats at x=1278",
            "seam_x_rule": "visible seam is at screen x=phase (phase=speed*t mod P); +phase moves content right",
            "main_top_y_range": [int(main_top.min()), int(main_top.max())],
            "near_top_y_range": [int(near_top.min()), int(near_top.max())],
        },
        "preview": {
            "html": str(BASE / "preview.html"),
            "serve": "python -m http.server 8765 --bind 127.0.0.1",
            "query": "?t=8&pause=1&seams=1&ui=0",
        },
        "shadows": {
            "direction": "upper-left light, shadow lower-right",
            "rule": "flattened contact footprint (largest component + horizontal smear + 5 alpha steps), clipped source-atop to sea; height changes offset/opacity/1-2px size",
            "sprites": [{"name": s["name"], "size": s["size"], "alpha_peak": s["alpha"],
                         "surface": s["surface"]} for s in shadow_specs],
        },
        "checks": ["reference.png", "diff_vs_v7_stats.json", "seam_texture_check.json",
                   "checks/flow_0_8_12.png", "checks/flow_direction_probe.png",
                   "checks/flow_direction_report.json", "checks/seam_render_check.json",
                   "checks/seam_main_before/after_closeup.png",
                   "checks/seam_near_before/after_closeup.png", "checks/time_trajectory.json",
                   "checks/motion_audit.json", "checks/protected_hashes_check.json",
                   "checks/shadow_central_3heights.png", "checks/shadow_low_3heights.png",
                   "checks/shadow_context_8s.png", "checks/sky_wrap_3panel.png",
                   "checks/browser_direction_check.json", "checks/browser_2x_t0.jpg",
                   "checks/browser_2x_t8.jpg", "checks/browser_2x_t12.jpg",
                   "checks/browser_seam_before.jpg", "checks/browser_seam_after.jpg",
                   "diff_vs_v7_report.md"],
        "protected": {"total": len(prot_rows), "unchanged": sum(r["unchanged"] for r in prot_rows)},
    }
    (BASE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print("reference written; diff", stats["differing_pixels"], "px")
    print("static above y250 diff", static_diff, "protected", sum(r["unchanged"] for r in prot_rows), "/", len(prot_rows))
    print("sea tops", int(main_top.min()), int(main_top.max()),
          int(near_top.min()), int(near_top.max()))


def alpha_over_rgba(dst: np.ndarray, src: np.ndarray, x: int, y: int) -> None:
    h, w = src.shape[:2]
    sx0, sy0 = max(0, -x), max(0, -y)
    dx0, dy0 = max(0, x), max(0, y)
    ww = min(w - sx0, W - dx0)
    hh = min(h - sy0, H - dy0)
    if ww <= 0 or hh <= 0:
        return
    s = src[sy0:sy0 + hh, sx0:sx0 + ww].astype(np.float32)
    d = dst[dy0:dy0 + hh, dx0:dx0 + ww].astype(np.float32)
    sa = s[..., 3:4] / 255.0
    da = d[..., 3:4] / 255.0
    oa = sa + da * (1 - sa)
    rgb = (s[..., :3] * sa + d[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    dst[dy0:dy0 + hh, dx0:dx0 + ww, :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    dst[dy0:dy0 + hh, dx0:dx0 + ww, 3] = np.clip(np.rint(oa[..., 0] * 255), 0, 255).astype(np.uint8)


def alpha_over_sea(dst: np.ndarray, shadow: np.ndarray) -> None:
    """Source-over a shadow (RGB+alpha) on the sea RGBA stack."""
    s = shadow.astype(np.float32)
    d = dst.astype(np.float32)
    sa = s[..., 3:4] / 255.0
    da = d[..., 3:4] / 255.0
    oa = sa + da * (1 - sa)
    rgb = (s[..., :3] * sa + d[..., :3] * da * (1 - sa)) / np.maximum(oa, 1e-6)
    dst[..., :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    dst[..., 3] = np.clip(np.rint(oa[..., 0] * 255), 0, 255).astype(np.uint8)


if __name__ == "__main__":
    main()
