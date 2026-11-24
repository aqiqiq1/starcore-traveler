#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Capture and verify DS03 in a real Chrome (file:// and temporary HTTP).

Outputs:
  reference.png / reference_2x.png
  checks/frames/*.png
  checks/*.png
  checks/*.json

The temporary HTTP server exists only for the split-file/standalone comparison
inside this script and is shut down before exit.  The delivered preview needs
no server.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import tempfile
import threading
import time
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from ds03_cdp import ChromeSession, TEMP_ROOT

ROOT = Path(__file__).resolve().parent
CHECKS = ROOT / "checks"
FRAMES = CHECKS / "frames"
CFG = json.loads((ROOT / "runtime_config.json").read_text(encoding="utf-8"))
S = CFG["render_scale"]
W, H = CFG["canvas"]
P = CFG["sea_period"]
DW, DH = W * S, H * S
STANDALONE = ROOT / "双击预览_DS03.html"
PREVIEW = ROOT / "preview.html"


def json_default(obj):
    if isinstance(obj, np.generic):
        return obj.item()
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, Path):
        return str(obj)
    raise TypeError(f"not JSON serializable: {type(obj)}")


def q(v: float) -> float:
    return round(v * S) / S


def d(v: float) -> int:
    return round(v * S)


def phase(speed: float, t: float) -> float:
    return q((speed * t) % P) % P


_RGBA_CACHE: dict[str, np.ndarray] = {}
_ALPHA_CACHE: dict[str, np.ndarray] = {}


def load_rgba(rel: str) -> np.ndarray:
    if rel not in _RGBA_CACHE:
        _RGBA_CACHE[rel] = np.array(Image.open(ROOT / rel).convert("RGBA"))
    return _RGBA_CACHE[rel]


def load_alpha(rel: str) -> np.ndarray:
    if rel not in _ALPHA_CACHE:
        _ALPHA_CACHE[rel] = load_rgba(rel)[:, :, 3] > 0
    return _ALPHA_CACHE[rel]


def rgba_to_img(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(arr, "RGBA")


def rgb_to_img(arr: np.ndarray) -> Image.Image:
    return Image.fromarray(arr.astype(np.uint8), "RGB")


def shot_to_arr(data: bytes) -> np.ndarray:
    return np.array(Image.open(BytesIO(data)).convert("RGB"))


def save_png(arr: np.ndarray, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    rgb_to_img(arr).save(path)


def url_with(base: str, t: float, mode: str | None = None, skip: str | None = None,
             seams: bool = False, selftest: bool = False, force: str | None = None,
             worst: str | None = None) -> str:
    sep = "&" if "?" in base else "?"
    parts = [f"t={t:.6f}", "pause=1", "ui=0"]
    if mode:
        parts.append("mode=" + mode)
    if skip:
        parts.append("skip=" + skip)
    if seams:
        parts.append("seams=1")
    if selftest:
        parts.append("selftest=1")
    if force:
        parts.append("force=" + force)
    if worst:
        parts.append("worst=" + worst)
    return base + sep + "&".join(parts)


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass


class QuietServer(ThreadingHTTPServer):
    daemon_threads = True

    def handle_error(self, request, client_address):
        pass


def start_http() -> tuple[ThreadingHTTPServer, str]:
    handler = partial(QuietHandler, directory=str(ROOT))
    server = QuietServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, f"http://127.0.0.1:{server.server_address[1]}/preview.html"


def capture(session: ChromeSession, url: str, label: str, save: bool = True) -> np.ndarray:
    session.navigate(url)
    data = session.screenshot()
    arr = shot_to_arr(data)
    if arr.shape != (DH, DW, 3):
        raise RuntimeError(f"{label}: screenshot is {arr.shape}, expected {(DH, DW, 3)}")
    if save:
        save_png(arr, FRAMES / f"{label}.png")
    return arr


def grab(session: ChromeSession, label: str, save: bool = True) -> np.ndarray:
    """Screenshot the current page without navigating (interaction checks)."""
    arr = shot_to_arr(session.screenshot())
    if arr.shape != (DH, DW, 3):
        raise RuntimeError(f"{label}: screenshot is {arr.shape}, expected {(DH, DW, 3)}")
    if save:
        save_png(arr, FRAMES / f"{label}.png")
    return arr


# ---------------------------------------------------------------------------
# geometry / pixel checks
# ---------------------------------------------------------------------------

def texture_pixel(asset: np.ndarray, phase_value: float, dx: int, dy: int):
    """Return the exact texture pixel a device pixel should show, or None."""
    start_primary = d(phase_value)
    start_left = d(phase_value - P)
    if dx >= start_primary and dx < start_primary + P * S:
        start = start_primary
    elif dx >= start_left and dx < start_left + P * S:
        start = start_left
    else:
        return None
    u = (dx - start) // S
    v = dy // S
    if not (0 <= u < asset.shape[1] and 0 <= v < asset.shape[0]):
        return None
    return asset[v, u]


def later_layer_hits(x: int, y: int, t: float) -> bool:
    """True if a layer after sea_main covers this logical pixel."""
    # arch_stone
    for item in CFG["static"]:
        if item["id"] == "arch_stone":
            lx, ly = x - item["offset"][0], y - item["offset"][1]
            if 0 <= lx < item["size"][0] and 0 <= ly < item["size"][1]:
                if load_alpha(item["file"])[ly, lx]:
                    return True
    # sea_near
    near = next(s for s in CFG["sea"] if s["name"] == "sea_near")
    pn = phase(near["speed"], t)
    near_px = texture_pixel(load_rgba(near["file"]), pn, x * S, y * S)
    if near_px is not None and near_px[3] > 0:
        return True
    # rock remnants (with the runtime component mask)
    rock = next(s for s in CFG["static"] if s["id"] == "rock_remnants_static")
    lx, ly = x - rock["offset"][0], y - rock["offset"][1]
    if 0 <= lx < rock["size"][0] and 0 <= ly < rock["size"][1]:
        if load_alpha(rock["file"])[ly, lx]:
            for rect in rock.get("exclude_mask_rects", []):
                if rect[0] <= lx < rect[2] and rect[1] <= ly < rect[3]:
                    break
            else:
                return True
    # debris
    for r in CFG["debris"]:
        bob = r["amp_y"] * math.sin(2 * math.pi * t / r["period"] + r["phase"])
        ry = q(r["y0"] + bob)
        lx, ly = x - r["x0"], y - ry
        if 0 <= lx < r["size"][0] and 0 <= ly < r["size"][1]:
            if load_alpha(r["file"])[int(ly), int(lx)]:
                return True
    return False


def cloud_roi_check(full: np.ndarray, sea_only: np.ndarray, t: float, roi_name: str) -> dict:
    roi = CFG["rois"][roi_name]
    main = next(s for s in CFG["sea"] if s["name"] == "sea_main")
    pm = phase(main["speed"], t)
    asset = load_rgba(main["file"])
    compared = 0
    mismatch_final = 0
    mismatch_seaonly = 0
    examples = []
    for y in range(roi[1], roi[3]):
        for x in range(roi[0], roi[2]):
            if later_layer_hits(x, y, t):
                continue
            for dx in (x * S, x * S + 1):
                for dy in (y * S, y * S + 1):
                    expected = texture_pixel(asset, pm, dx, dy)
                    if expected is None or expected[3] != 255:
                        continue
                    compared += 1
                    got = full[dy, dx]
                    if not np.array_equal(got, expected[:3]):
                        mismatch_final += 1
                        if len(examples) < 5:
                            examples.append(
                                {
                                    "x": x,
                                    "y": y,
                                    "device": [dx, dy],
                                    "expected": expected[:3].tolist(),
                                    "got": got.tolist(),
                                }
                            )
                    if not np.array_equal(got, sea_only[dy, dx]):
                        mismatch_seaonly += 1
    return {
        "times": t,
        "roi": roi_name,
        "roi_box": roi,
        "phase_main": pm,
        "compared_device_pixels": compared,
        "mismatch_final_vs_current_cloud": mismatch_final,
        "mismatch_final_vs_seaonly": mismatch_seaonly,
        "examples": examples,
        "ok": compared > 0 and mismatch_final == 0 and mismatch_seaonly == 0,
    }


def building_mask(frame: np.ndarray, base: np.ndarray) -> np.ndarray:
    return np.any(frame.astype(np.int16) != base.astype(np.int16), axis=2)


def bridge_bottom(mask: np.ndarray, x: int) -> float | None:
    dx = x * S
    col = mask[:, dx]
    ys = np.nonzero(col)[0]
    if len(ys) == 0:
        return None
    return (ys[-1] + 1) / S


def best_shift(m0: np.ndarray, m1: np.ndarray, max_shift: int = 260) -> dict:
    heights, width = m0.shape
    best = (-1.0, 0)
    scores = []
    for shift in range(0, max_shift + 1):
        if shift == 0:
            a = m0
            b = m1
        else:
            a = m0[:, : width - shift]
            b = m1[:, shift:]
        denom = np.count_nonzero(a)
        if denom == 0:
            continue
        score = np.count_nonzero(a & b) / denom
        scores.append([shift, round(float(score), 6)])
        if score > best[0]:
            best = (float(score), shift)
    return {
        "shift_device_px": best[1],
        "shift_logical_px": best[1] / S,
        "score": best[0],
        "peak_scores": sorted(scores, key=lambda x: x[1], reverse=True)[:5],
    }


def best_shift_color(a: np.ndarray, b: np.ndarray, max_shift: int = 260) -> dict:
    heights, width = a.shape[:2]
    best = (-1e9, 0)
    scores = []
    for shift in range(0, max_shift + 1):
        aa = a[:, : width - shift].astype(np.int16)
        bb = b[:, shift:].astype(np.int16)
        mae = float(np.mean(np.abs(aa - bb)))
        score = -mae
        scores.append([shift, round(score, 6)])
        if score > best[0]:
            best = (score, shift)
    return {
        "shift_device_px": best[1],
        "shift_logical_px": best[1] / S,
        "mae": -best[0],
        "peak_scores": sorted(scores, key=lambda x: x[1], reverse=True)[:5],
    }


def color_palette(asset: np.ndarray) -> set[tuple[int, int, int]]:
    alpha = asset[:, :, 3] > 0
    return set(map(tuple, asset[:, :, :3][alpha].tolist()))


def alpha_gap(upper: dict, lower: dict, x0: int, x1: int,
              dy_upper: float = 0.0, dy_lower: float = 0.0) -> dict:
    """Minimum vertical air gap between two source alpha masks over x0..x1-1.

    dy_upper/dy_lower are the rendered offsets of those groups at the sampled
    time.  Using each group's own alpha avoids the old heuristic mixing a roof
    fragment of the upper group into the lower bridge run.
    """
    a = load_alpha(upper["file"])
    b = load_alpha(lower["file"])
    gaps = []
    for x in range(x0, x1):
        ax = x - upper["offset"][0]
        bx = x - lower["offset"][0]
        if not (0 <= ax < a.shape[1] and 0 <= bx < b.shape[1]):
            continue
        ya = np.nonzero(a[:, ax])[0]
        yb = np.nonzero(b[:, bx])[0]
        if not len(ya) or not len(yb):
            continue
        upper_bottom = upper["offset"][1] + int(ya.max()) + 1 + dy_upper
        lower_top = lower["offset"][1] + int(yb.min()) + dy_lower
        gaps.append(
            {
                "x": x,
                "upper": [upper["offset"][1] + int(ya.min()) + dy_upper,
                          upper["offset"][1] + int(ya.max()) + 1 + dy_upper],
                "lower": [lower["offset"][1] + int(yb.min()) + dy_lower,
                          lower["offset"][1] + int(yb.max()) + 1 + dy_lower],
                "gap_px": lower_top - upper_bottom,
            }
        )
    if not gaps:
        return {"min_gap_px": None, "best_x": None, "ok": False, "samples": []}
    best = min(gaps, key=lambda item: item["gap_px"])
    return {
        "min_gap_px": float(best["gap_px"]),
        "best_x": best["x"],
        "samples": gaps[:12],
        "dy_upper": dy_upper,
        "dy_lower": dy_lower,
        "ok": best["gap_px"] >= 2.0,
    }


def bridge_static_check(frames: dict[str, np.ndarray], states: dict[str, dict]) -> dict:
    """Pixel-fixed check for the two complete bridge bodies in groupsonly frames.

    The alpha mask comes from the source PNG at the art offset.  All frames must
    agree exactly on every non-transparent bridge pixel; opaque pixels must also
    equal the source RGB, proving the bridge is at its original offset with no
    rotation/scale.
    """
    result = {"ok": True, "groups": {}, "frames": sorted(frames)}
    for gid in ("G1", "G2"):
        g = next(item for item in CFG["groups"] if item["id"] == gid)
        img = load_rgba(g["file"])
        if img.shape[:2] != (g["size"][1], g["size"][0]):
            raise RuntimeError(f"{gid}: PNG size differs from config")
        alpha = img[:, :, 3]
        mask = np.repeat(np.repeat(alpha > 0, S, axis=0), S, axis=1)
        opaque = np.repeat(np.repeat(alpha == 255, S, axis=0), S, axis=1)
        rgb = np.repeat(np.repeat(img[:, :, :3], S, axis=0), S, axis=1)
        x0 = d(g["offset"][0])
        y0 = d(g["offset"][1])
        h, w = mask.shape
        ref = frames["groups_t0"][y0:y0 + h, x0:x0 + w]
        pixel_mismatch = 0
        color_mismatch = 0
        dy_values = []
        for label, frame in frames.items():
            region = frame[y0:y0 + h, x0:x0 + w]
            pixel_mismatch += int(np.count_nonzero(np.any(region != ref, axis=2) & mask))
            color_mismatch += int(np.count_nonzero(np.any(region != rgb, axis=2) & opaque))
            st = states.get(label)
            if st is not None:
                item = next(gstate for gstate in st["groups"] if gstate["id"] == gid)
                dy_values.append(item["dyRendered"])
        item_ok = pixel_mismatch == 0 and color_mismatch == 0 and all(v == 0 for v in dy_values)
        result["groups"][gid] = {
            "offset": g["offset"],
            "size": g["size"],
            "opaque_pixels": int(np.count_nonzero(mask)),
            "pixel_mismatch": pixel_mismatch,
            "source_rgb_mismatch_on_opaque": color_mismatch,
            "dyRendered_values": sorted(set(dy_values)),
            "ok": item_ok,
        }
        result["ok"] = result["ok"] and item_ok
    return result


BASELINE_RUNTIME = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\ds03-small-ruins-motion-49cbce0481fd499b933b2946e23a3402"
)


def compare_runtime_baseline() -> dict:
    """Compare this build with the saved pre-adjustment runtime baseline."""
    if not BASELINE_RUNTIME.is_dir():
        return {"ok": None, "note": "baseline directory not available", "path": str(BASELINE_RUNTIME)}
    base_cfg = json.loads((BASELINE_RUNTIME / "runtime_config.json").read_text(encoding="utf-8-sig"))
    sections = ["canvas", "render_scale", "sea_period", "base", "static", "sky", "sea", "shadows", "debris", "stack"]
    section_equal = {name: base_cfg.get(name) == CFG.get(name) for name in sections}
    group_diffs = []
    for old in base_cfg["groups"]:
        new = next(item for item in CFG["groups"] if item["id"] == old["id"])
        changed_non_float = sorted(
            key for key in set(old) | set(new)
            if key != "float" and old.get(key) != new.get(key)
        )
        float_changed = sorted(
            key for key in set(old.get("float", {})) | set(new.get("float", {}))
            if old.get("float", {}).get(key) != new.get("float", {}).get(key)
        )
        group_diffs.append({"id": old["id"], "non_float_changes": changed_non_float, "float_changed_fields": float_changed})
    group_ok = all(not row["non_float_changes"] for row in group_diffs) and len(group_diffs) == 5
    asset_rows = json.loads((BASELINE_RUNTIME / "asset_hashes.json").read_text(encoding="utf-8-sig"))
    asset_bad = []
    for row in asset_rows:
        path = Path(row["path"])
        got = sha256_file(path)
        if got.lower() != row["sha256"].lower():
            asset_bad.append({"path": str(path), "expected": row["sha256"], "got": got})
    return {
        "ok": all(section_equal.values()) and group_ok and len(asset_rows) == 24 and not asset_bad,
        "baseline_path": str(BASELINE_RUNTIME),
        "sections_equal": section_equal,
        "groups_non_float_equal": group_ok,
        "group_diffs": group_diffs,
        "asset_count": len(asset_rows),
        "asset_hashes_unchanged": not asset_bad,
        "asset_bad": asset_bad,
        "changed_config_sections": [name for name, same in section_equal.items() if not same],
    }


def sha256_file(path: Path) -> str:
    import hashlib

    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def measured_crossing_period(samples: list, gid: str) -> float | None:
    series = []
    for t, groups in samples:
        item = next(g for g in groups if g[0] == gid)
        series.append((float(t), float(item[1])))
    crossings = []
    for (t0, v0), (t1, v1) in zip(series, series[1:]):
        if v0 < 0 <= v1:
            span = v1 - v0
            frac = (-v0 / span) if span else 0.0
            crossings.append(t0 + frac * (t1 - t0))
    if len(crossings) < 2:
        return None
    diffs = [b - a for a, b in zip(crossings, crossings[1:]) if b - a > 1.0]
    return round(sum(diffs) / len(diffs), 3) if diffs else None




# ---------------------------------------------------------------------------
# PIL panels
# ---------------------------------------------------------------------------

def font(size: int = 16):
    for path in (
        r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\msyh.ttc",
    ):
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            pass
    return ImageFont.load_default()


FONT = font(16)
SMALL = font(13)


def crop_panel(frame: np.ndarray, box: list[int], scale: int, label: str) -> Image.Image:
    x0, y0, x1, y1 = box
    crop = frame[y0 * S:y1 * S, x0 * S:x1 * S]
    target = ((x1 - x0) * scale, (y1 - y0) * scale)
    im = Image.fromarray(crop.astype(np.uint8), "RGB").resize(target, Image.NEAREST)
    w, h = im.size
    panel = Image.new("RGB", (w, h + 24), (14, 20, 24))
    panel.paste(im, (0, 24))
    ImageDraw.Draw(panel).text((6, 4), label, fill=(220, 235, 240), font=SMALL)
    return panel


def montage(panels: list[Image.Image], columns: int, background=(8, 12, 15)) -> Image.Image:
    gap = 8
    rows = math.ceil(len(panels) / columns)
    cell_w = max(p.width for p in panels)
    cell_h = max(p.height for p in panels)
    out = Image.new("RGB", (columns * cell_w + (columns + 1) * gap,
                            rows * cell_h + (rows + 1) * gap), background)
    draw = ImageDraw.Draw(out)
    for i, panel in enumerate(panels):
        col = i % columns
        row = i // columns
        x = gap + col * (cell_w + gap)
        y = gap + row * (cell_h + gap)
        out.paste(panel, (x, y))
        draw.rectangle([x - 1, y - 1, x + panel.width, y + panel.height], outline=(45, 64, 74))
    return out


def downsample(arr: np.ndarray) -> np.ndarray:
    return arr[::2, ::2]


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep-frames", action="store_true", help="keep checks/frames/*.png")
    args = ap.parse_args()

    CHECKS.mkdir(parents=True, exist_ok=True)
    if FRAMES.exists():
        shutil.rmtree(FRAMES)
    FRAMES.mkdir(parents=True)
    for pattern in ("_test_*.png", "_cdp_*.png", "test_*.png", "pier_joint_extreme_10x.png"):
        for stale in CHECKS.glob(pattern):
            stale.unlink()

    server, http_base = start_http()
    empty_dir = Path(tempfile.mkdtemp(prefix="ds03_empty_", dir=str(TEMP_ROOT)))
    empty_file = empty_dir / STANDALONE.name
    shutil.copyfile(STANDALONE, empty_file)
    empty_url = empty_file.as_uri()
    file_base = STANDALONE.as_uri()

    times = {
        "t0": 0.0,
        "t4": 4.0,
        "t8": 8.0,
        "t12": 12.0,
        "t30": 30.0,
        "t60": 60.0,
    }
    seam_t = float(CFG["inspection"]["seam_t"])
    seam_before = seam_t - 0.8
    seam_after = seam_t + 0.8
    cycle_t = float(CFG["inspection"]["cycle_t"])
    near_cycle_t = P / 7.2
    sky_wrap_t = float(CFG["inspection"]["sky_wrap_t"])
    up_t = float(CFG["inspection"]["bridge_static_t1"])
    down_t = float(CFG["inspection"]["bridge_static_t2"])
    island_t = float(CFG["inspection"]["island_min_t"])
    g3g1_t = float(CFG["inspection"]["g3_g1_min_t"])
    joint_t = float(CFG["inspection"]["bridge_joint_t"])

    frames: dict[str, np.ndarray] = {}
    try:
        with ChromeSession() as browser:
            # Full frames at the required times.
            for name, t in times.items():
                frames["full_" + name] = capture(
                    browser, url_with(file_base, t), "full_" + name
                )
            for name, t in (("seam_before", seam_before), ("seam", seam_t), ("seam_after", seam_after)):
                frames["full_" + name] = capture(
                    browser, url_with(file_base, t), "full_" + name
                )
            frames["full_joint"] = capture(browser, url_with(file_base, joint_t), "full_joint")

            # Same frames with only base + sea layers, for exact cloud comparison.
            for name, t in list(times.items()) + [
                ("seam_before", seam_before),
                ("seam", seam_t),
                ("seam_after", seam_after),
            ]:
                frames["sea_" + name] = capture(
                    browser, url_with(file_base, t, mode="seaonly"), "sea_" + name
                )

            # No-cloud and per-layer review frames.
            frames["nocloud_t0"] = capture(browser, url_with(file_base, 0.0, mode="noclouds"), "nocloud_t0")
            frames["nocloud_up"] = capture(browser, url_with(file_base, up_t, mode="noclouds"), "nocloud_up")
            frames["nocloud_down"] = capture(browser, url_with(file_base, down_t, mode="noclouds"), "nocloud_down")
            frames["base_t0"] = capture(browser, url_with(file_base, 0.0, mode="baseonly"), "base_t0")
            frames["rock_t0"] = capture(browser, url_with(file_base, 0.0, mode="rockonly"), "rock_t0")

            group_states = {}
            group_captures = [
                ("groups_t0", 0.0),
                ("groups_down", down_t),
                ("groups_up", up_t),
                ("groups_t12", 12.0),
                ("groups_island", island_t),
                ("groups_t34_74", 34.74),
                ("groups_t50", 50.0),
                ("groups_t60", 60.0),
                ("groups_g3g1", g3g1_t),
                ("groups_joint", joint_t),
            ]
            for name, t in group_captures:
                frames[name] = capture(browser, url_with(file_base, t, mode="groupsonly"), name)
                group_states[name] = browser.eval("window.DS03.state()")

            forced_captures = [
                ("groups_force_up", down_t, "up", None),
                ("groups_force_down", down_t, "down", None),
                ("groups_worst_bridge", down_t, None, "bridge"),
                ("groups_worst_island", island_t, None, "island"),
            ]
            for name, t, force, worst in forced_captures:
                frames[name] = capture(
                    browser, url_with(file_base, t, mode="groupsonly", force=force, worst=worst), name
                )
                group_states[name] = browser.eval("window.DS03.state()")

            # Real interaction path: resume -> pause -> reset -> seek.
            browser.navigate(url_with(file_base, 0.0, mode="groupsonly"))
            frames["groups_resume_a"] = grab(browser, "groups_resume_a")
            group_states["groups_resume_a"] = browser.eval("window.DS03.state()")
            browser.eval("window.DS03.resume()")
            time.sleep(0.35)
            frames["groups_resume_live"] = grab(browser, "groups_resume_live")
            group_states["groups_resume_live"] = browser.eval("window.DS03.state()")
            browser.eval("window.DS03.pause()")
            frames["groups_resume_paused"] = grab(browser, "groups_resume_paused")
            group_states["groups_resume_paused"] = browser.eval("window.DS03.state()")
            browser.eval("document.getElementById('reset').click()")
            time.sleep(0.12)
            browser.eval("window.DS03.pause()")
            frames["groups_reset"] = grab(browser, "groups_reset")
            group_states["groups_reset"] = browser.eval("window.DS03.state()")
            browser.eval("window.DS03.setTime(12, true)")
            frames["groups_seek12"] = grab(browser, "groups_seek12")
            group_states["groups_seek12"] = browser.eval("window.DS03.state()")

            # Seam markers (both shelves visible).
            for name, t in (("seam_before", seam_before), ("seam", seam_t), ("seam_after", seam_after)):
                frames["seam_mark_" + name] = capture(
                    browser, url_with(file_base, t, mode="seaonly", seams=True), "seam_mark_" + name
                )

            # Sky wrap sequence.
            for name, t in (
                ("sky_wrap_before", sky_wrap_t - 0.1),
                ("sky_wrap_at", sky_wrap_t),
                ("sky_wrap_after", sky_wrap_t + 0.1),
            ):
                frames[name] = capture(browser, url_with(file_base, t, mode="skyonly"), name)

            # Shadow height states, sampled where the source rocks are at their
            # high/low extremes.
            shadow_times = {
                "shadow_central_high": 5.625,   # debris_central bob -4
                "shadow_central_low": 1.875,    # debris_central bob +4
                "shadow_low_high": 4.752,       # debris_low bob -3.5
                "shadow_low_low": 0.502,        # debris_low bob +3.5
            }
            shadow_states = {}
            for name, t in shadow_times.items():
                frames[name] = capture(browser, url_with(file_base, t), name)
                shadow_states[name] = browser.eval("window.DS03.state()")

            # Actual period equality: only one shelf each time, no shadows.
            frames["main_0"] = capture(
                browser, url_with(file_base, 0.0, mode="seaonly", skip="seaNear,shadows"), "main_0"
            )
            frames["main_cycle"] = capture(
                browser, url_with(file_base, cycle_t, mode="seaonly", skip="seaNear,shadows"), "main_cycle"
            )
            frames["near_0"] = capture(
                browser, url_with(file_base, 0.0, mode="seaonly", skip="seaMain,shadows"), "near_0"
            )
            frames["near_cycle"] = capture(
                browser, url_with(file_base, near_cycle_t, mode="seaonly", skip="seaMain,shadows"), "near_cycle"
            )

            # Direction frames: full (actual composite), no extra modes.
            frames["sky_t0"] = capture(browser, url_with(file_base, 0.0, mode="skyonly"), "sky_t0")
            frames["sky_t8"] = capture(browser, url_with(file_base, 8.0, mode="skyonly"), "sky_t8")
            frames["sky_t12"] = capture(browser, url_with(file_base, 12.0, mode="skyonly"), "sky_t12")

            # Standalone selftest (actual file://, data URIs).
            browser.navigate(url_with(file_base, 0.0, selftest=True))
            selftest = browser.run_selftest()
            (CHECKS / "browser_selftest.json").write_text(
                json.dumps(selftest, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
            )

            # Split-file page over a temporary localhost server, same times.
            frames["split_t0"] = capture(
                browser, url_with(http_base, 0.0), "split_t0"
            )
            frames["split_t8"] = capture(
                browser, url_with(http_base, 8.0), "split_t8"
            )
            browser.navigate(url_with(http_base, 0.0, selftest=True))
            selftest_split = browser.run_selftest()
            (CHECKS / "browser_selftest_split.json").write_text(
                json.dumps(selftest_split, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
            )

            # Copy the single file to an otherwise empty directory and load it.
            frames["empty_t8"] = capture(browser, url_with(empty_url, 8.0), "empty_t8")
            empty_state = browser.eval(
                "({title:document.title, protocol:location.protocol, failed:window.DS03?window.DS03.state().failed:null, assets:window.DS03?window.DS03.assetKeys.length:null})"
            )

            # The split-file preview must also work directly from file://.
            frames["split_file_t0"] = capture(
                browser, url_with(PREVIEW.as_uri(), 0.0), "split_file_t0"
            )
            frames["split_file_t8"] = capture(
                browser, url_with(PREVIEW.as_uri(), 8.0), "split_file_t8"
            )

            # URL parameter check at a non-zero time.
            browser.navigate(url_with(file_base, 8.0, seams=True))
            param_state = browser.eval(
                "({t:window.DS03.state().t, playing:window.DS03.state().playing, hudHidden:document.getElementById('hud').classList.contains('hidden'), assets:window.DS03.assetKeys.length})"
            )

            # Dense runtime sampling for measured zero-crossing periods (not a
            # label-only check): 0.25 s x 60 s of the real draw loop.
            browser.navigate(url_with(file_base, 0.0, mode="groupsonly"))
            period_samples = browser.eval(
                "(() => { const out=[]; for (let i=0; i<=240; i++) {"
                " const tt=i*0.25; window.DS03.setTime(tt, true);"
                " const s=window.DS03.state();"
                " out.push([tt, s.groups.map(g=>[g.id, g.dyFormula, g.dyRendered])]);"
                " } window.DS03.setTime(0, true); return out; })()"
            )
    finally:
        server.shutdown()
        server.server_close()
        shutil.rmtree(empty_dir, ignore_errors=True)

    # ------------------------------------------------------------------
    # reference / check images
    # ------------------------------------------------------------------
    ref2 = frames["full_t0"]
    save_png(ref2, ROOT / "reference_2x.png")
    save_png(downsample(ref2), ROOT / "reference.png")

    # Full frames 0/8/12.
    montage(
        [
            crop_panel(frames["full_t0"], [0, 0, 640, 360], 1, "t=0 s"),
            crop_panel(frames["full_t8"], [0, 0, 640, 360], 1, "t=8 s  (sky +x, sea +x)"),
            crop_panel(frames["full_t12"], [0, 0, 640, 360], 1, "t=12 s"),
        ],
        3,
    ).save(CHECKS / "flow_0_8_12.png")

    # Left/right foot at the required times.
    foot_times = [
        ("t=0", frames["full_t0"]),
        ("t=4", frames["full_t4"]),
        ("t=8", frames["full_t8"]),
        ("t=12", frames["full_t12"]),
        ("t=30", frames["full_t30"]),
        ("t=60", frames["full_t60"]),
    ]
    for side, box in (("left", [25, 235, 165, 305]), ("right", [440, 235, 580, 305])):
        panels = [crop_panel(arr, box, 4, label) for label, arr in foot_times]
        montage(panels, 3).save(CHECKS / f"{side}_foot_cloud_times_4x.png")

    # No-cloud right foot vs cloud-on.
    no_cloud_panel = crop_panel(frames["nocloud_t0"], [430, 225, 590, 310], 4, "clouds off: no static white block")
    cloud_panel = crop_panel(frames["full_t0"], [430, 225, 590, 310], 4, "clouds on t=0")
    montage([no_cloud_panel, cloud_panel], 2).save(CHECKS / "right_foot_cloud_off_vs_on_4x.png")

    # Both bridges, same dynamic cloud layer (two times).
    panels = []
    for label, arr in (("t=0", frames["full_t0"]), ("t=8", frames["full_t8"])):
        panels.append(crop_panel(arr, [25, 235, 165, 305], 3, "left " + label))
        panels.append(crop_panel(arr, [440, 235, 580, 305], 3, "right " + label))
    montage(panels, 2).save(CHECKS / "both_bridges_same_cloud_3x.png")

    # Bridge static (old up/down sample times): the two bridge bodies do not move.
    panels = [
        crop_panel(frames["nocloud_up"], [0, 120, 640, 320], 2, "bridge static A t=7.125: G1/G2 dy 0"),
        crop_panel(frames["nocloud_down"], [0, 120, 640, 320], 2, "bridge static B t=2.375: G1/G2 dy 0"),
    ]
    montage(panels, 1).save(CHECKS / "ruins_float_joint_up_down_2x.png")

    # Bridge feet across normal times: the opaque bridge pixels are fixed.
    bridge_time_panels = []
    for label, key in (
        ("t=0", "groups_t0"),
        ("t=12", "groups_t12"),
        ("t=26.683", "groups_island"),
        ("t=64.47", "groups_joint"),
    ):
        bridge_time_panels.append(crop_panel(frames[key], [25, 220, 285, 305], 2, "left bridge " + label))
        bridge_time_panels.append(crop_panel(frames[key], [434, 220, 571, 305], 2, "right bridge " + label))
    montage(bridge_time_panels, 2).save(CHECKS / "bridge_static_times_4x.png")

    # Island / column gap and G3/G1 gap.
    montage(
        [
            crop_panel(frames["groups_island"], [460, 160, 550, 215], 10, "G5/桥 fixed actual t=26.683"),
            crop_panel(frames["groups_g3g1"], [25, 180, 115, 220], 10, "G3/桥 fixed actual t=2.375"),
        ],
        2,
    ).save(CHECKS / "ruins_alpha_gaps_10x.png")

    # Bridge foot joint: full cloud cover + the fixed bridge mask at the same
    # time, so the reserve and the absence of a sky gap are both visible.
    montage(
        [
            crop_panel(frames["full_joint"], [35, 270, 70, 305], 8, "G1 x49 full: cloud top 282, bridge bottom 300"),
            crop_panel(frames["groups_joint"], [35, 270, 70, 305], 8, "G1 groups: static bottom 300"),
            crop_panel(frames["full_joint"], [462, 270, 497, 305], 8, "G2 x476 full: cloud top 278, bridge bottom 300"),
            crop_panel(frames["groups_joint"], [462, 270, 497, 305], 8, "G2 groups: static bottom 300"),
        ],
        2,
    ).save(CHECKS / "pier_joint_extreme_8x.png")

    # Sea seam with markers.
    panels = [
        crop_panel(frames["seam_mark_seam_before"], [0, 230, 640, 360], 1, "seam before t=58.922  red main 247.5 / yellow near 424.0"),
        crop_panel(frames["seam_mark_seam"], [0, 230, 640, 360], 1, "seam t=59.722  red main 250.8 / yellow near 430.0"),
        crop_panel(frames["seam_mark_seam_after"], [0, 230, 640, 360], 1, "seam after t=60.522  red main 254.2 / yellow near 435.8"),
    ]
    montage(panels, 1).save(CHECKS / "sea_seam_three_1x.png")

    # Sky wrap three-panel.
    panels = [
        crop_panel(frames["sky_wrap_before"], [0, 0, 640, 140], 1, "sky before wrap t=43.771"),
        crop_panel(frames["sky_wrap_at"], [0, 0, 640, 140], 1, "sky at wrap t=43.871 (right bank off-screen)"),
        crop_panel(frames["sky_wrap_after"], [0, 0, 640, 140], 1, "sky after wrap t=43.971"),
    ]
    montage(panels, 1).save(CHECKS / "sky_wrap_3panel.png")

    # Rock filter proof: keep the legal remnants, show the source component that
    # the runtime filter removes (source PNG itself is untouched).
    rock = next(s for s in CFG["static"] if s["id"] == "rock_remnants_static")
    rock_src = load_rgba(rock["file"])
    src_crop = rock_src[152:160, 38:48]
    src_big = Image.fromarray(src_crop, "RGBA").resize((240, 192), Image.NEAREST)
    src_panel = Image.new("RGB", (240, 216), (14, 20, 24))
    src_panel.paste(src_big.convert("RGB"), (0, 24))
    sd = ImageDraw.Draw(src_panel)
    sd.text((6, 4), "source PNG: red = filtered 5 px blade", fill=(230, 230, 230), font=SMALL)
    sd.rectangle([72, 96, 168, 144], outline=(255, 80, 80), width=2)
    runtime_panel = crop_panel(
        frames["rock_t0"],
        [rock["offset"][0] + 38, rock["offset"][1] + 152,
         rock["offset"][0] + 48, rock["offset"][1] + 160],
        24,
        "runtime rockonly: same box, blade absent",
    )
    kept_panel = crop_panel(
        frames["rock_t0"], [330, 265, 395, 325], 8,
        "runtime kept remnants (components 3/4)",
    )
    montage([kept_panel, src_panel, runtime_panel], 3).save(CHECKS / "rock_filter_8x.png")

    # Shadow high/low (the source rocks are at their actual bob extremes).
    shadow_panels = [
        crop_panel(frames["shadow_central_high"], [295, 235, 365, 300], 4, "central high: lighter, +right/+down, taller"),
        crop_panel(frames["shadow_central_low"], [295, 235, 365, 300], 4, "central low: stronger, -left/-up"),
        crop_panel(frames["shadow_low_high"], [225, 280, 275, 335], 5, "low rock high: alpha x0.88, +right/+down"),
        crop_panel(frames["shadow_low_low"], [225, 280, 275, 335], 5, "low rock low: alpha x1.0, contact"),
    ]
    montage(shadow_panels, 2).save(CHECKS / "shadows_height_context_4x.png")

    # DS02 right foot vs DS03 (read-only old reference vs new t=0).
    old_ref = np.array(
        Image.open(ROOT.parent / "云海遗迹背景动态重制_DS02" / "reference_2x.png").convert("RGB")
    )
    montage(
        [
            crop_panel(old_ref, [440, 225, 590, 310], 4, "DS02 old: island_overlay static white cloud"),
            crop_panel(frames["full_t0"], [440, 225, 590, 310], 4, "DS03: both bridges before dynamic sea"),
        ],
        2,
    ).save(CHECKS / "right_foot_old_ds02_vs_ds03_4x.png")

    # ------------------------------------------------------------------
    # numeric checks
    # ------------------------------------------------------------------
    cloud_checks = []
    for name, t in list(times.items()) + [
        ("seam_before", seam_before),
        ("seam", seam_t),
        ("seam_after", seam_after),
    ]:
        for roi in ("left_foot", "right_foot"):
            cloud_checks.append(cloud_roi_check(frames["full_" + name], frames["sea_" + name], t, roi))
    cloud_report = {
        "ok": all(item["ok"] for item in cloud_checks),
        "checks": cloud_checks,
        "note": "ROI restricted to current sea_main alpha with no later layer; expected pixel is the actual sea_main texture at that phase.",
    }
    (CHECKS / "cloud_occlusion_report.json").write_text(
        json.dumps(cloud_report, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
    )

    # Direction: exact-pixel period, plus correlation of actual full sky/sea bands.
    period_main = int(np.max(np.abs(frames["main_0"].astype(np.int16) - frames["main_cycle"].astype(np.int16))))
    period_near = int(np.max(np.abs(frames["near_0"].astype(np.int16) - frames["near_cycle"].astype(np.int16))))

    base = frames["base_t0"]
    diff0 = np.any(frames["full_t0"].astype(np.int16) != base.astype(np.int16), axis=2)
    diff8 = np.any(frames["full_t8"].astype(np.int16) != base.astype(np.int16), axis=2)
    diff12 = np.any(frames["full_t12"].astype(np.int16) != base.astype(np.int16), axis=2)
    sky_shift0_8 = best_shift(diff0[70:240, 0:600], diff8[70:240, 0:600], 220)
    sky_shift0_12 = best_shift(diff0[70:240, 0:600], diff12[70:240, 0:600], 260)

    # Use sea-only frames for unambiguous main/near bands.
    sea_base_diff = np.any(frames["sea_t0"].astype(np.int16) != base.astype(np.int16), axis=2)
    sea8_diff = np.any(frames["sea_t8"].astype(np.int16) != base.astype(np.int16), axis=2)
    sea12_diff = np.any(frames["sea_t12"].astype(np.int16) != base.astype(np.int16), axis=2)
    main_band = slice(480, 576)  # logical y 240..288; near starts at 289
    near_band = slice(640, 720)  # logical y 320..360; near opaque, use colour feature
    main_shift0_8 = best_shift(sea_base_diff[main_band, :], sea8_diff[main_band, :], 180)
    main_shift0_12 = best_shift(sea_base_diff[main_band, :], sea12_diff[main_band, :], 240)
    near_shift0_8 = best_shift_color(frames["sea_t0"][near_band, :], frames["sea_t8"][near_band, :], 260)
    near_shift0_12 = best_shift_color(frames["sea_t0"][near_band, :], frames["sea_t12"][near_band, :], 360)

    # Sea-near full-frame bottom band cross-check (actual composite).
    full_near0_8 = best_shift_color(frames["full_t0"][near_band, :], frames["full_t8"][near_band, :], 260)
    full_near0_12 = best_shift_color(frames["full_t0"][near_band, :], frames["full_t12"][near_band, :], 360)

    direction_report = {
        "ok": (
            period_main == 0
            and period_near == 0
            and sky_shift0_8["shift_device_px"] > 0
            and sky_shift0_12["shift_device_px"] > 0
            and main_shift0_8["shift_device_px"] > 0
            and main_shift0_12["shift_device_px"] > 0
            and near_shift0_8["shift_device_px"] > 0
            and near_shift0_12["shift_device_px"] > 0
        ),
        "method": "binary difference mask vs baseonly; peak overlap shift in device px; positive = right",
        "sky_full_band_0_8": sky_shift0_8,
        "sky_full_band_0_12": sky_shift0_12,
        "sea_main_band_0_8": main_shift0_8,
        "sea_main_band_0_12": main_shift0_12,
        "sea_near_band_0_8": near_shift0_8,
        "sea_near_band_0_12": near_shift0_12,
        "sea_near_full_0_8": full_near0_8,
        "sea_near_full_0_12": full_near0_12,
        "expected": {
            "sky_near_bank_0_8_logical": 6.2 * 8,
            "sky_near_bank_0_12_logical": 6.2 * 12,
            "main_0_8_logical": 4.2 * 8,
            "main_0_12_logical": 4.2 * 12,
            "near_0_8_logical": 7.2 * 8,
            "near_0_12_logical": 7.2 * 12,
        },
        "cycle_exact_diff": {
            "main_max_channel_diff": period_main,
            "near_max_channel_diff": period_near,
            "main_cycle_t": cycle_t,
            "near_cycle_t": near_cycle_t,
        },
    }
    (CHECKS / "direction_report.json").write_text(
        json.dumps(direction_report, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
    )

    # Float / gaps.
    base = frames["base_t0"]
    group_frame_names = [
        "groups_t0",
        "groups_down",
        "groups_up",
        "groups_t12",
        "groups_island",
        "groups_t34_74",
        "groups_t50",
        "groups_t60",
        "groups_g3g1",
        "groups_joint",
        "groups_force_up",
        "groups_force_down",
        "groups_worst_bridge",
        "groups_worst_island",
        "groups_resume_a",
        "groups_resume_live",
        "groups_resume_paused",
        "groups_reset",
        "groups_seek12",
    ]
    masks = {name: building_mask(frames[name], base) for name in group_frame_names}
    g1_up_bottom = bridge_bottom(masks["groups_up"], 49)
    g1_down_bottom = bridge_bottom(masks["groups_down"], 49)
    g2_up_bottom = bridge_bottom(masks["groups_up"], 476)
    g2_down_bottom = bridge_bottom(masks["groups_down"], 476)
    g1_joint_bottom = bridge_bottom(masks["groups_joint"], 49)
    g2_joint_bottom = bridge_bottom(masks["groups_joint"], 476)

    g5 = next(g for g in CFG["groups"] if g["id"] == "G5")
    g2 = next(g for g in CFG["groups"] if g["id"] == "G2")
    g3 = next(g for g in CFG["groups"] if g["id"] == "G3")
    g1 = next(g for g in CFG["groups"] if g["id"] == "G1")

    def rendered_dy(frame_name: str, gid: str) -> float:
        st = group_states[frame_name]
        return next(item for item in st["groups"] if item["id"] == gid)["dyRendered"]

    island_gap = alpha_gap(
        g5, g2, 474, 482,
        dy_upper=rendered_dy("groups_island", "G5"),
        dy_lower=rendered_dy("groups_island", "G2"),
    )
    g3g1_gap = alpha_gap(
        g3, g1, 31, 101,
        dy_upper=rendered_dy("groups_g3g1", "G3"),
        dy_lower=rendered_dy("groups_g3g1", "G1"),
    )

    def group_bounds(name, box):
        x0, y0, x1, y1 = box
        sub = masks[name][y0 * S:y1 * S, x0 * S:x1 * S]
        ys, xs = np.nonzero(sub)
        if len(xs) == 0:
            return None
        return {
            "left": (x0 * S + xs.min()) / S,
            "right": (x0 * S + xs.max() + 1) / S,
            "top": (y0 * S + ys.min()) / S,
            "bottom": (y0 * S + ys.max() + 1) / S,
        }

    group_boxes = {
        "G1": [25, 250, 285, 310],
        "G2": [434, 250, 571, 310],
        "G3": [31, 160, 101, 202],
        "G4": [244, 170, 310, 204],
        "G5": [444, 130, 535, 188],
    }
    normal_names = [
        "groups_t0",
        "groups_down",
        "groups_up",
        "groups_t12",
        "groups_island",
        "groups_t34_74",
        "groups_t50",
        "groups_t60",
        "groups_g3g1",
        "groups_joint",
    ]
    visible_motion = {}
    for gid, box in group_boxes.items():
        bounds = [group_bounds(name, box) for name in normal_names]
        bounds = [item for item in bounds if item is not None]
        dys = []
        for name in normal_names:
            st = group_states[name]
            item = next(gstate for gstate in st["groups"] if gstate["id"] == gid)
            dys.append(item["dyRendered"])
        dy_range = max(dys) - min(dys)
        max_abs_dy = max(abs(value) for value in dys)
        top_values = sorted(set(item["top"] for item in bounds))
        top_range = max(top_values) - min(top_values)
        bottom_values = sorted(set(item["bottom"] for item in bounds))
        bottom_range = max(bottom_values) - min(bottom_values)
        distinct = sorted(set(dys))
        if gid in ("G1", "G2"):
            ok = dy_range == 0 and top_range == 0 and bottom_range == 0 and distinct == [0]
        else:
            # Peak-to-peak is at most 1.0 (from -0.5 to +0.5); the requested
            # limit is on absolute offset from the art position: |dy| <= 0.5.
            ok = (
                max_abs_dy <= 0.5
                and dy_range > 0
                and top_range <= 1.0
                and top_range > 0
                and len(distinct) >= 2
            )
        visible_motion[gid] = {
            "dy_values": distinct,
            "peak_to_peak_dy": dy_range,
            "max_abs_dy": max_abs_dy,
            "offset_limit_px": 0.5,
            "top_values": top_values,
            "top_peak_to_peak": top_range,
            "bottom_peak_to_peak": bottom_range,
            "frame_count": len(normal_names),
            "ok": ok,
        }

    bridge_static = bridge_static_check(
        {name: frames[name] for name in group_frame_names}, group_states
    )

    # Joint bridge foot: no base-sky pixel in the stone->cloud strip at pier columns.
    joint_t = float(CFG["inspection"]["bridge_joint_t"])
    main = next(s for s in CFG["sea"] if s["name"] == "sea_main")
    pm = phase(main["speed"], joint_t)
    base_joint = frames["base_t0"]
    joint_gap_px = 0
    joint_rows = []
    for x, bottom in ((49, g1_joint_bottom), (476, g2_joint_bottom)):
        if bottom is None:
            continue
        cloud_top = main["top"][((x - round(pm)) % P + P) % P]
        for dx in (x * S, x * S + 1):
            for dy in range(int(round(cloud_top * S)), int(round(bottom * S))):
                if np.array_equal(frames["full_joint"][dy, dx], base_joint[dy, dx]):
                    joint_gap_px += 1
        joint_rows.append({"x": x, "cloud_top": cloud_top, "bridge_bottom": bottom, "overlap": bottom - cloud_top})

    # Rock filter numeric.
    rock_mask = building_mask(frames["rock_t0"], base)
    excluded_rect = [245, 330, 249, 332]
    ex_count = int(
        np.count_nonzero(
            rock_mask[
                excluded_rect[1] * S:excluded_rect[3] * S,
                excluded_rect[0] * S:excluded_rect[2] * S,
            ]
        )
    )
    kept_count = int(np.count_nonzero(rock_mask))

    # Palette check: building layers contain no sea-cloud colors.
    sea_palette = color_palette(load_rgba("common/sea_main.png")) | color_palette(load_rgba("common/sea_near.png"))
    group_cloud_hits = {}
    for g in CFG["groups"]:
        arr = load_rgba(g["file"])
        alpha = arr[:, :, 3] > 0
        colors = set(map(tuple, arr[:, :, :3][alpha].tolist()))
        group_cloud_hits[g["id"]] = len(colors & sea_palette)

    no_cloud_roi = frames["nocloud_t0"][250 * S:283 * S, 455 * S:560 * S]
    no_cloud_colors = set(map(tuple, no_cloud_roi.reshape(-1, 3).tolist()))
    no_cloud_sea_hits = len(no_cloud_colors & sea_palette)

    # Actual source-alpha air at the two previously tight spots.
    baseline_g5_g2 = alpha_gap(g5, g2, 474, 482)
    baseline_g3_g1 = alpha_gap(g3, g1, 31, 101)

    def quantized_search(gap_a: dict, gap_b: dict, baseline_gap: float,
                         duration: float = 360.0, step: float = 0.002):
        def qdy(g, t):
            if g["float"].get("enabled") is False:
                return 0.0
            return round(
                g["float"]["amp"]
                * math.sin(2 * math.pi * (t + g["float"]["phase"]) / g["float"]["period"])
                * S
            ) / S

        best = None
        t = 0.0
        while t <= duration:
            da = qdy(gap_a, t)
            db = qdy(gap_b, t)
            gap = baseline_gap - (da - db)
            if best is None or gap < best["gap_px"]:
                best = {"gap_px": gap, "t": t, "dy_a": da, "dy_b": db}
            t += step
        best["baseline_gap_px"] = baseline_gap
        best["duration_s"] = duration
        best["step_s"] = step
        best["ok"] = best["gap_px"] >= 2.0
        return best

    search_g5_g2 = quantized_search(g5, g2, baseline_g5_g2["min_gap_px"])
    search_g3_g1 = quantized_search(g3, g1, baseline_g3_g1["min_gap_px"])

    float_report = {
        "ok": (
            bridge_static["ok"]
            and island_gap["ok"]
            and g3g1_gap["ok"]
            and joint_gap_px == 0
            and ex_count == 0
            and kept_count > 0
            and all(v == 0 for v in group_cloud_hits.values())
            and no_cloud_sea_hits == 0
            and search_g5_g2["ok"]
            and search_g3_g1["ok"]
            and all(item["ok"] for item in visible_motion.values())
        ),
        "actual_times": {
            "bridge_static_a": up_t,
            "bridge_static_b": down_t,
            "island_min": island_t,
            "g3_g1_min": g3g1_t,
            "bridge_joint": joint_t,
        },
        "groups_visible_motion": visible_motion,
        "bridge_static": bridge_static,
        "bridge_bottom_actual": {
            "G1_static_a": g1_up_bottom,
            "G1_static_b": g1_down_bottom,
            "G2_static_a": g2_up_bottom,
            "G2_static_b": g2_down_bottom,
            "G1_joint": g1_joint_bottom,
            "G2_joint": g2_joint_bottom,
            "G1_delta_logical": (g1_down_bottom - g1_up_bottom) if g1_up_bottom and g1_down_bottom else None,
            "G2_delta_logical": (g2_down_bottom - g2_up_bottom) if g2_up_bottom and g2_down_bottom else None,
        },
        "g5_g2_actual_min": island_gap,
        "g3_g1_actual_min": g3g1_gap,
        "g5_g2_source_alpha_baseline": baseline_g5_g2,
        "g3_g1_source_alpha_baseline": baseline_g3_g1,
        "bridge_joint": {
            "rows": joint_rows,
            "base_sky_pixels_in_stone_to_cloud_strip": joint_gap_px,
        },
        "rock_filter": {
            "excluded_rect_world": excluded_rect,
            "excluded_device_pixels": ex_count,
            "kept_device_pixels": kept_count,
        },
        "cloud_palette_pixels_in_groups": group_cloud_hits,
        "no_cloud_right_foot_sea_palette_hits": no_cloud_sea_hits,
        "quantized_search_g5_g2": search_g5_g2,
        "quantized_search_g3_g1": search_g3_g1,
    }
    (CHECKS / "float_gap_report.json").write_text(
        json.dumps(float_report, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
    )

    baseline_compare = compare_runtime_baseline()

    # Shadow rule report (actual browser state at the sampled heights).
    def pick_shadow(key, name):
        return next(s for s in shadow_states[key]["shadows"] if s["name"] == name)

    central_high = pick_shadow("shadow_central_high", "shadow_central")
    central_low = pick_shadow("shadow_central_low", "shadow_central")
    low_high = pick_shadow("shadow_low_high", "shadow_low")
    low_low = pick_shadow("shadow_low_low", "shadow_low")
    shadow_ok = (
        central_high["alpha"] < central_low["alpha"]
        and central_high["sy"] > central_low["sy"]
        and central_high["sx"] > central_low["sx"]
        and central_high["height"] >= central_low["height"]
        and low_high["alpha"] < low_low["alpha"]
        and low_high["sy"] > low_low["sy"]
        and low_high["sx"] > low_low["sx"]
    )
    shadows_report = {
        "ok": shadow_ok,
        "note": "actual DS03.state().shadows at the sampled rock heights; source rules unchanged from DS02",
        "central_high": central_high,
        "central_low": central_low,
        "low_high": low_high,
        "low_low": low_low,
        "times": shadow_times,
    }
    (CHECKS / "shadows_report.json").write_text(
        json.dumps(shadows_report, ensure_ascii=False, indent=2, default=json_default) + "\n",
        encoding="utf-8",
    )

    # Integrity: split == standalone, empty dir == standalone, selftest.
    integrity = {
        "standalone_file": STANDALONE.name,
        "single_file_protocol": selftest.get("protocol"),
        "single_file_embedded_assets": selftest.get("embeddedAssetCount"),
        "single_file_asset_keys": selftest.get("assetKeyCount"),
        "single_file_failed_assets": selftest.get("failed"),
        "single_file_errors": selftest.get("errors"),
        "single_file_external_requests": selftest.get("externalRequests"),
        "single_file_scripts": selftest.get("scripts"),
        "single_file_links": selftest.get("links"),
        "pause_resume": selftest.get("pauseResume"),
        "play_button": selftest.get("playButton"),
        "scrub": selftest.get("scrub"),
        "inspection_buttons": selftest.get("inspectionButtons"),
        "reset_button": selftest.get("resetButton"),
        "seam_button": selftest.get("seamBefore"),
        "hide_ui": selftest.get("hideUI"),
        "split_failed_assets": selftest_split.get("failed"),
        "split_errors": selftest_split.get("errors"),
        "split_t0_matches_standalone": bool(np.array_equal(frames["split_t0"], frames["full_t0"])),
        "split_t8_matches_standalone": bool(np.array_equal(frames["split_t8"], frames["full_t8"])),
        "split_file_t0_matches_standalone": bool(np.array_equal(frames["split_file_t0"], frames["full_t0"])),
        "split_file_t8_matches_standalone": bool(np.array_equal(frames["split_file_t8"], frames["full_t8"])),
        "empty_dir_t8_matches_standalone": bool(np.array_equal(frames["empty_t8"], frames["full_t8"])),
        "empty_dir_runtime": empty_state,
        "param_state": param_state,
        "temporary_http_only_for_test": http_base,
    }
    integrity["ok"] = (
        integrity["single_file_protocol"] == "file:"
        and integrity["single_file_embedded_assets"] == 24
        and not integrity["single_file_failed_assets"]
        and not integrity["single_file_errors"]
        and not integrity["single_file_external_requests"]
        and not integrity["single_file_scripts"]
        and not integrity["single_file_links"]
        and selftest.get("playButton", {}).get("ok")
        and selftest.get("scrub", {}).get("ok")
        and selftest.get("inspectionButtons", {}).get("ok")
        and integrity["split_t0_matches_standalone"]
        and integrity["split_t8_matches_standalone"]
        and integrity["split_file_t0_matches_standalone"]
        and integrity["split_file_t8_matches_standalone"]
        and integrity["empty_dir_t8_matches_standalone"]
        and empty_state.get("failed") == []
        and param_state.get("t") == 8.0
        and param_state.get("playing") is False
        and param_state.get("hudHidden") is True
        and param_state.get("assets") == 24
    )
    (CHECKS / "integrity_report.json").write_text(
        json.dumps(integrity, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
    )

    # Build/art/common integrity summaries are already in build_runtime_report.json.
    build_report = json.loads((CHECKS / "build_runtime_report.json").read_text(encoding="utf-8"))
    standalone_report = json.loads((CHECKS / "standalone_build_report.json").read_text(encoding="utf-8"))

    previous_periods = {}
    if BASELINE_RUNTIME.is_dir():
        old_cfg = json.loads((BASELINE_RUNTIME / "runtime_config.json").read_text(encoding="utf-8-sig"))
        previous_periods = {g["id"]: g["float"]["period"] for g in old_cfg["groups"]}

    period_rows = {}
    for gid in ("G3", "G4", "G5"):
        g = next(item for item in CFG["groups"] if item["id"] == gid)
        measured = measured_crossing_period(period_samples, gid)
        expected = g["float"]["period"]
        period_rows[gid] = {
            "previous_period_s": previous_periods.get(gid),
            "current_period_s": expected,
            "measured_zero_crossing_period_s": measured,
            "slower_than_previous": (
                previous_periods.get(gid) is not None and expected > previous_periods[gid]
            ),
            "ok": measured is not None and abs(measured - expected) <= 0.25,
        }
    period_ok = all(row["ok"] and row["slower_than_previous"] for row in period_rows.values())

    motion_report = {
        "ok": (
            float_report["ok"]
            and period_ok
            and baseline_compare.get("ok") is True
            and build_report["baseline"]["ok"] == 108
            and build_report["art_layers"]["ok"] == 8
            and build_report["common_copies"]["ok"] == 16
            and integrity["ok"]
        ),
        "scope": "runtime motion only; no PNG, art_manifest, Godot or other page changes",
        "notes": [
            "G1/G2 use an enabled=false early-out in preview.js before force/worst branches; they are fixed at the art offset, with no rotation or scale.",
            "G4 used amp 0.6 before and already quantized to a 0.5 rendered peak, so this round does not claim its actual peak decreased; it is 0.30/22 s versus 0.6/12 s and therefore quieter.",
            "Rendered offset is within -0.5..+0.5 logical px for G3/G4/G5; peak-to-peak is therefore up to 1.0 logical px (2 device px), which is the intended quantization span, not a larger amplitude.",
            "art_manifest.json amp_max values are old-asset upper bounds, not the current runtime motion rule; runtime_config.json groups[].float is current.",
        ],
        "rules": {
            g["id"]: {
                "enabled": g["float"].get("enabled", True),
                "amp_formula_px": g["float"]["amp"],
                "period_s": g["float"]["period"],
                "phase_s": g["float"]["phase"],
                "rendered_quantum_px": CFG["quantization"]["logical_quantum"],
            }
            for g in CFG["groups"]
        },
        "periods": period_rows,
        "bridge_static": {
            "ok": bridge_static["ok"],
            "frame_count": len(bridge_static["frames"]),
            "groups": {
                gid: {
                    "offset": row["offset"],
                    "opaque_pixels": row["opaque_pixels"],
                    "pixel_mismatch": row["pixel_mismatch"],
                    "source_rgb_mismatch_on_opaque": row["source_rgb_mismatch_on_opaque"],
                    "dyRendered_values": row["dyRendered_values"],
                    "ok": row["ok"],
                }
                for gid, row in bridge_static["groups"].items()
            },
            "modes": [
                "normal paused times",
                "pause/resume",
                "reset",
                "seek 12 s",
                "force=up",
                "force=down",
                "worst=bridge",
                "worst=island",
            ],
        },
        "small_ruins_actual": {
            gid: visible_motion[gid] for gid in ("G3", "G4", "G5")
        },
        "gaps": {
            "G5_G2_actual_min_px": island_gap["min_gap_px"],
            "G5_G2_source_alpha_baseline_px": baseline_g5_g2["min_gap_px"],
            "G3_G1_actual_min_px": g3g1_gap["min_gap_px"],
            "G3_G1_source_alpha_baseline_px": baseline_g3_g1["min_gap_px"],
            "bridge_joint_cloud_overlap": joint_rows,
            "base_sky_pixels_in_stone_to_cloud_strip": joint_gap_px,
        },
        "protection": {
            "baseline_runtime_config": {
                "sections_equal": baseline_compare.get("sections_equal"),
                "groups_non_float_equal": baseline_compare.get("groups_non_float_equal"),
                "group_float_changes": baseline_compare.get("group_diffs"),
            },
            "asset_hashes_24_unchanged": baseline_compare.get("asset_hashes_unchanged"),
            "protected_baseline_108": build_report["baseline"]["ok"],
            "art_layers_8": build_report["art_layers"]["ok"],
            "common_copies_16": build_report["common_copies"]["ok"],
        },
        "browser": {
            "standalone": STANDALONE.name,
            "protocol": integrity["single_file_protocol"],
            "embedded_assets": integrity["single_file_embedded_assets"],
            "external_requests": integrity["single_file_external_requests"],
            "failed_assets": integrity["single_file_failed_assets"],
            "split_matches_standalone_t0_t8": (
                integrity["split_t0_matches_standalone"] and integrity["split_t8_matches_standalone"]
            ),
            "file_and_empty_dir_match": (
                integrity["split_file_t0_matches_standalone"]
                and integrity["split_file_t8_matches_standalone"]
                and integrity["empty_dir_t8_matches_standalone"]
            ),
        },
    }
    (CHECKS / "motion_adjustment_report.json").write_text(
        json.dumps(motion_report, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
    )

    summary = {
        "ok": all(
            [
                cloud_report["ok"],
                direction_report["ok"],
                float_report["ok"],
                shadows_report["ok"],
                integrity["ok"],
                build_report["ok"],
                standalone_report["ok"],
                motion_report["ok"],
            ]
        ),
        "cloud_occlusion_ok": cloud_report["ok"],
        "direction_ok": direction_report["ok"],
        "float_gap_ok": float_report["ok"],
        "motion_adjustment_ok": motion_report["ok"],
        "shadow_ok": shadows_report["ok"],
        "integrity_ok": integrity["ok"],
        "protected_baseline": build_report["baseline"]["ok"],
        "art_layers": build_report["art_layers"]["ok"],
        "common_copies": build_report["common_copies"]["ok"],
        "standalone_asset_count": standalone_report["asset_count"],
    }
    (CHECKS / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2, default=json_default) + "\n", encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2, default=json_default))
    print("check images:", ", ".join(sorted(p.name for p in CHECKS.glob("*.png"))))
    if not args.keep_frames:
        # Keep the frames by default: they are compact evidence and useful for review.
        pass
    return 0 if summary["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
