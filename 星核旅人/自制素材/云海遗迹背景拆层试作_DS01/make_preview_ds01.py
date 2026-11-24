# -*- coding: utf-8 -*-
"""DS01 preview: compose the manifest layers into a limited-loop GIF and
extreme-displacement inspection sheets.  Does not touch the game."""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

BASE = Path(__file__).resolve().parent
CHECKS = BASE / "checks"
W, H = 640, 360
FRAMES = 72
GIF_MS = 90
PAD = 8

settings = {
    "sky_clouds":   {"dx": 6, "dy": 0, "period": 72, "phase": 0.0},
    "cloud_sea_far": {"dx": 2, "dy": 1, "period": 72, "phase": 1.0},
    "cloud_sea_near": {"dx": 4, "dy": 0, "period": 36, "phase": 0.0},
    "debris_central": {"dx": 1, "dy": 2, "period": 72, "phase": 0.6},
    "debris_cluster": {"dx": 1, "dy": 1, "period": 72, "phase": 2.4},
    "debris_tiny":    {"dx": 0, "dy": 1, "period": 72, "phase": 3.3},
    "debris_low":     {"dx": 1, "dy": 1, "period": 72, "phase": 4.2},
}


def load() -> tuple[dict, list[dict]]:
    manifest = json.loads((BASE / "manifest.json").read_text(encoding="utf-8"))
    layers = {}
    for item in manifest["stack_order"]:
        im = Image.open(BASE / item["file"])
        if item["name"] == "base_static":
            layers[item["name"]] = im.convert("RGB")
        else:
            layers[item["name"]] = im.convert("RGBA")
    return manifest, manifest["stack_order"], layers


def compose(stack, layers, offs) -> Image.Image:
    canvas = layers["base_static"].convert("RGBA")
    for item in stack[1:]:
        im = layers[item["name"]]
        ox, oy = item["initial_offset"]
        dx, dy = offs.get(item["name"], (0, 0))
        canvas.paste(im, (ox + dx, oy + dy), im)
    return canvas.convert("RGB")


def compose_sky_only(stack, layers, dx: int) -> Image.Image:
    """Base + sky clouds only: the edge check must show no foreground or UI."""
    canvas = layers["base_static"].convert("RGBA")
    item = next(i for i in stack if i["name"] == "sky_clouds")
    ox, oy = item["initial_offset"]
    im = layers["sky_clouds"]
    canvas.paste(im, (ox + dx, oy), im)
    return canvas.convert("RGB")


def offsets_at(t: int) -> dict[str, tuple[int, int]]:
    out = {}
    for name, s in settings.items():
        if name not in ("sky_clouds", "cloud_sea_far", "cloud_sea_near") and not name.startswith("debris_"):
            continue
        a = 2 * math.pi * t / s["period"] + s["phase"]
        out[name] = (round(s["dx"] * math.sin(a)), round(s["dy"] * math.sin(a)))
    return out


def fixed_offsets(sign=1, stress=False) -> dict[str, tuple[int, int]]:
    if not stress:
        amps = {k: (v["dx"], v["dy"]) for k, v in settings.items()}
    else:
        amps = {
            "sky_clouds": (12, 0),
            "cloud_sea_far": (8, 2),
            "cloud_sea_near": (10, 0),
            "debris_central": (6, 4),
            "debris_cluster": (4, 3),
            "debris_tiny": (0, 3),
            "debris_low": (4, 2),
        }
    return {k: (sign * dx, sign * dy) for k, (dx, dy) in amps.items()}


def label_strip(width, height, text, bg=(16, 20, 24)):
    im = Image.new("RGB", (width, height), bg)
    d = ImageDraw.Draw(im)
    d.text((6, 4), text, fill=(225, 232, 238))
    return im


def main() -> None:
    CHECKS.mkdir(parents=True, exist_ok=True)
    manifest, stack, layers = load()

    # Frames.
    frames = []
    for t in range(FRAMES):
        frames.append(compose(stack, layers, offsets_at(t)))

    # A single global 256-colour palette avoids per-frame palette flicker.
    pal_src = frames[0].quantize(colors=256, method=Image.Quantize.MEDIANCUT,
                                 dither=Image.Dither.NONE)
    pframes = [f.quantize(palette=pal_src, dither=Image.Dither.NONE) for f in frames]
    gif = BASE / "preview_background.gif"
    pframes[0].save(gif, save_all=True, append_images=pframes[1:],
                    duration=GIF_MS, loop=0, optimize=False, disposal=2)
    print("gif", gif.stat().st_size, "bytes", FRAMES, "frames")

    # 12-frame contact sheet (half size).
    picks = [0, 6, 12, 18, 24, 30, 36, 42, 48, 54, 60, 66]
    tw, th = W // 2, H // 2
    cols, rows = 4, 3
    gap, bar = 6, 18
    sheet = Image.new("RGB", (cols * tw + (cols - 1) * gap,
                              rows * (th + bar) + (rows - 1) * gap), (16, 20, 24))
    for i, t in enumerate(picks):
        cx, cy = i % cols, i // cols
        x = cx * (tw + gap)
        y = cy * (th + bar + gap)
        sheet.paste(label_strip(tw, bar, f"step {t:02d} / {FRAMES}  t={t * GIF_MS / 1000:.2f}s"), (x, y))
        sheet.paste(frames[t].resize((tw, th), Image.Resampling.NEAREST), (x, y + bar))
    sheet.save(CHECKS / "contact_sheet_12frames.png", optimize=True)

    # Extreme checks.  Intended maxima are simultaneous here on purpose.
    panels = [
        ("initial (all offsets 0)", compose(stack, layers, {})),
        ("intended max +", compose(stack, layers, fixed_offsets(1, False))),
        ("intended max -", compose(stack, layers, fixed_offsets(-1, False))),
        ("stress x2+ (not safe range)", compose(stack, layers, fixed_offsets(1, True))),
    ]
    sheet = Image.new("RGB", (2 * W + 8, 2 * (H + 20) + 8), (16, 20, 24))
    for i, (txt, im) in enumerate(panels):
        cx, cy = i % 2, i // 2
        x, y = cx * (W + 8), cy * (H + 20 + 8)
        sheet.paste(label_strip(W, 20, txt), (x, y))
        sheet.paste(im, (x, y + 20))
    sheet.save(CHECKS / "extreme_displacement_check.png", optimize=True)

    # Extra 2x detail of the two pier bases and the low rock from the stress frame.
    stress = compose(stack, layers, fixed_offsets(1, True))
    crops = [
        ("left pier / cloud edge", stress.crop((20, 250, 220, 350))),
        ("right pier / cloud edge", stress.crop((430, 250, 600, 350))),
        ("low rock / rebuilt cloud", stress.crop((210, 275, 320, 345))),
    ]
    scale = 4
    dw = sum(c.width * scale for _, c in crops) + 8 * (len(crops) - 1)
    dh = max(c.height * scale for _, c in crops) + 18
    detail = Image.new("RGB", (dw, dh), (16, 20, 24))
    x = 0
    for txt, c in crops:
        detail.paste(label_strip(c.width * scale, 18, txt), (x, 0))
        detail.paste(c.resize((c.width * scale, c.height * scale), Image.Resampling.NEAREST), (x, 18))
        x += c.width * scale + 8
    detail.save(CHECKS / "stress_detail_4x.png", optimize=True)

    # Sky-cloud edge check: the original canvas crop line must stay outside the
    # viewport at dx +/- 6.  Base + sky only (no foreground, characters or UI).
    sky_item = next(i for i in stack if i["name"] == "sky_clouds")
    sky_pad_l = int(sky_item["padding"]["left"])
    sky_pad_r = int(sky_item["padding"]["right"])
    sky_im = layers["sky_clouds"]
    sky_np = np.array(sky_im)
    left_margin_ok = bool(np.array_equal(
        sky_np[:, :sky_pad_l], np.repeat(sky_np[:, sky_pad_l:sky_pad_l + 1], sky_pad_l, axis=1)))
    right_margin_ok = bool(np.array_equal(
        sky_np[:, sky_pad_l + W:], np.repeat(sky_np[:, sky_pad_l + W - 1:sky_pad_l + W], sky_pad_r, axis=1)))
    assert left_margin_ok and right_margin_ok, "sky margin is not a clean edge continuation"

    panels = [
        ("left edge / initial (dx 0)", compose_sky_only(stack, layers, 0).crop((0, 45, 80, 135))),
        ("left edge / dx +6", compose_sky_only(stack, layers, 6).crop((0, 45, 80, 135))),
        ("left edge / dx -6", compose_sky_only(stack, layers, -6).crop((0, 45, 80, 135))),
        ("right edge / initial (dx 0)", compose_sky_only(stack, layers, 0).crop((560, 45, 640, 135))),
        ("right edge / dx -6", compose_sky_only(stack, layers, -6).crop((560, 45, 640, 135))),
        ("right edge / dx +6", compose_sky_only(stack, layers, 6).crop((560, 45, 640, 135))),
    ]
    scale = 6
    cols = 3
    gap = 10
    margin = 10
    bar = 18
    title_h = 24
    cw, ch = panels[0][1].size
    pw, ph = cw * scale, ch * scale
    rows = 2
    sheet = Image.new("RGB", (margin * 2 + cols * pw + (cols - 1) * gap,
                              title_h + margin * 2 + rows * (bar + ph) + (rows - 1) * gap),
                      (16, 20, 24))
    d = ImageDraw.Draw(sheet)
    d.text((margin, 6),
           "sky_clouds edge check, 6x nearest; panel border = 640x360 viewport edge; base + sky only",
           fill=(225, 232, 238))
    for i, (txt, c) in enumerate(panels):
        cx, cy = i % cols, i // cols
        x = margin + cx * (pw + gap)
        y = title_h + margin + cy * (bar + ph + gap)
        d.text((x + 4, y + 4), txt, fill=(225, 232, 238))
        sheet.paste(c.resize((pw, ph), Image.Resampling.NEAREST), (x, y + bar))
        d.rectangle([x, y + bar, x + pw - 1, y + bar + ph - 1], outline=(235, 240, 245))
    sheet.save(CHECKS / "sky_edge_fixed_check.png", optimize=True)

    # Machine-readable preview parameters.
    stored = Image.open(gif)
    stored_frames = stored.n_frames
    stored_ms = 0
    for i in range(stored_frames):
        stored.seek(i)
        stored_ms += int(stored.info.get("duration", GIF_MS))
    meta = {
        "gif": "preview_background.gif",
        "size": [W, H],
        "time_steps": FRAMES,
        "time_step_ms": GIF_MS,
        "total_duration_ms": FRAMES * GIF_MS,
        "gif_stored_frames": stored_frames,
        "gif_stored_total_ms": stored_ms,
        "loop": "infinite",
        "motion": settings,
        "safe_ranges_note": "sine amplitudes; integer rounding per frame; not an infinite scrolling system",
        "sky_layer": {
            "file": "layers/sky_clouds.png",
            "size": list(sky_im.size),
            "initial_offset": list(sky_item["initial_offset"]),
            "side_margin": [sky_pad_l, sky_pad_r],
            "safe_range_dx": 6,
            "edge_continuation_clean": bool(left_margin_ok and right_margin_ok),
            "crop_line_note": "the margin repeats the edge column, so at dx=+6 the margin|original boundary at screen x=6 (right: x=633 at dx=-6) is pixel-identical across it; no visible crop edge or sky strip; not an infinite cloud texture",
        },
        "sky_edge_check": "checks/sky_edge_fixed_check.png",
        "stress": "checks/extreme_displacement_check.png panel 3 uses 2x amplitudes to expose fill; not an approved range",
        "animation_status": "frames inspected; continuous playback not asserted by the generator",
        "gif_palette": "one global 256-colour palette, dithering off; still layers are full RGB PNG",
        "merge_note": "GIF writer merges identical consecutive integer-pixel states and doubles their duration; total time is preserved",
    }
    (CHECKS / "preview_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
