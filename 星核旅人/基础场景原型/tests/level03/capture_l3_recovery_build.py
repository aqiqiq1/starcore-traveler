"""Build the recovery-transition GIF and review sheet from real engine frames.

Python is the project-approved interpreter:
  D:\\minic\\envs\\2024212971\\python.exe

The frames come from capture_l3_recovery_20261116.gd (640x360 normal viewport).
This file only reads screenshots/l3_recovery_20261116/ and writes new review
artifacts in the same new folder; it never touches old screenshots.
"""
from __future__ import annotations

import csv
import json
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
SHOT = ROOT / "screenshots" / "l3_recovery_20261116"
MANIFEST = SHOT / "MANIFEST.txt"
STRIP_DIR = SHOT / "strip"

STRIP_RE = re.compile(
    r"^STRIP (f\d+\.png) ms=(\d+) phase=(\w+) alpha=([\d.]+) hud_alpha=([\d.]+) "
    r"reset_alpha=(-?[\d.]+) reset_count=(\d+) finished=(\d+) kind=(\w*) "
    r"\| x=(-?[\d.]+) y=(-?[\d.]+) tint=([\d.]+) hits=(\d+) "
    r"guard=(\w+) suspended=(\w+) paused=(\w+)$"
)


def parse_strip():
    rows = []
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        m = STRIP_RE.match(line)
        if not m:
            continue
        rows.append({
            "file": m.group(1),
            "ms": int(m.group(2)),
            "phase": m.group(3),
            "alpha": float(m.group(4)),
            "reset_alpha": float(m.group(6)),
            "reset_count": int(m.group(7)),
            "finished": int(m.group(8)),
            "kind": m.group(9),
            "x": float(m.group(10)),
            "y": float(m.group(11)),
            "tint": float(m.group(12)),
            "hits": int(m.group(13)),
            "guard": m.group(14),
            "suspended": m.group(15),
        })
    return rows


def load_font(size=16):
    path = ROOT / "assets" / "fonts" / "tutorial_zh.ttf"
    if path.exists():
        try:
            return ImageFont.truetype(str(path), size)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    rows = parse_strip()
    if not rows:
        raise SystemExit("no STRIP rows in MANIFEST")
    frames = []
    for row in rows:
        p = STRIP_DIR / row["file"]
        img = Image.open(p).convert("RGB")
        if img.size != (640, 360):
            raise SystemExit(f"{p.name} is {img.size}, expected 640x360")
        frames.append(img)

    # GIF: keep the real sampled cadence (clamped so one slow save cannot stall
    # the preview). The per-frame alpha is in the CSV/review sheet.
    durations = []
    for i, row in enumerate(rows):
        nxt = rows[i + 1]["ms"] if i + 1 < len(rows) else row["ms"] + 30
        durations.append(max(10, min(80, nxt - row["ms"])))
    frames[0].save(
        SHOT / "transition.gif",
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=False,
    )

    # Review sheet: selected real frames with state labels outside the pixels.
    def pick(pred, fallback):
        for i, row in enumerate(rows):
            if pred(row):
                return i
        return fallback

    def pick_last(pred, fallback):
        for i in range(len(rows) - 1, -1, -1):
            if pred(rows[i]):
                return i
        return fallback

    picks = [
        pick(lambda r: r["alpha"] < 0.2 and r["phase"] == "fade_out", 0),
        pick(lambda r: r["alpha"] >= 0.5 and r["phase"] == "fade_out", 1),
        pick_last(lambda r: r["phase"] == "fade_out" and r["reset_count"] == 0, 2),
        pick(lambda r: r["reset_count"] >= 1, 3),
        pick(lambda r: r["phase"] == "fade_in" and r["alpha"] <= 0.8, 4),
        pick(lambda r: r["phase"] == "fade_in" and r["alpha"] <= 0.5, 5),
        pick(lambda r: r["phase"] == "fade_in" and r["alpha"] <= 0.2, 6),
        len(rows) - 1,
    ]
    picks = list(dict.fromkeys(picks))
    font = load_font(13)
    label_h = 36
    cols = 2
    rows_n = (len(picks) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 640, rows_n * (360 + label_h)), (12, 16, 20))
    draw = ImageDraw.Draw(sheet)
    for row_index in range(rows_n):
        cy = row_index * (360 + label_h)
        pair = picks[row_index * cols:(row_index + 1) * cols]
        for col, frame_i in enumerate(pair):
            row = rows[frame_i]
            cx = col * 640
            label = (
                f"{row['file']} ms={row['ms']} a={row['alpha']:.3f} {row['phase']} "
                f"r={row['reset_count']} x={row['x']:.0f},y={row['y']:.0f} "
                f"susp={'T' if row['suspended'] == 'true' else 'F'}"
            )
            draw.text((cx + 8, cy + 9), label, fill=(230, 236, 235), font=font)
            sheet.paste(frames[frame_i], (cx, cy + label_h))
    title_h = 34
    titled = Image.new("RGB", (sheet.width, sheet.height + title_h), (12, 16, 20))
    titled.paste(sheet, (0, title_h))
    title_font = load_font(18)
    ImageDraw.Draw(titled).text(
        (8, 7),
        "L3 recovery strip: real engine frames (setup state, not a full playthrough)",
        fill=(244, 205, 99), font=title_font)
    titled.save(SHOT / "transition_review.png")

    with (SHOT / "fade_alpha.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    # Independent pixel checks on the saved keyframes.
    black = Image.open(SHOT / "a04_black_reset.png").convert("RGB")
    black_max = max(black.getextrema()[0][1], black.getextrema()[1][1], black.getextrema()[2][1])
    c1 = Image.open(SHOT / "c01_pause_over_cover.png").convert("RGB")
    c2 = Image.open(SHOT / "c02_pause_clock_frozen.png").convert("RGB")
    pause_diff = 0 if ImageChops.difference(c1, c2).getbbox() is None else 1

    reset_frame = next((r for r in rows if r["reset_count"] >= 1), None)
    alpha_one = [r for r in rows if r["alpha"] >= 0.999]
    summary = {
        "strip_frames": len(rows),
        "strip_total_ms": rows[-1]["ms"],
        "strip_first_alpha": rows[0]["alpha"],
        "strip_last_alpha": rows[-1]["alpha"],
        "alpha_one_frames": len(alpha_one),
        "reset_frame": reset_frame["file"] if reset_frame else None,
        "reset_ms": reset_frame["ms"] if reset_frame else None,
        "reset_alpha": reset_frame["reset_alpha"] if reset_frame else None,
        "reset_x": reset_frame["x"] if reset_frame else None,
        "reset_y": reset_frame["y"] if reset_frame else None,
        "a04_black_max_channel": black_max,
        "pause_pair_pixel_diff": pause_diff,
        "picked_frames": [rows[i]["file"] for i in picks],
    }
    (SHOT / "ANALYSIS.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "L3 recovery analysis (from saved engine frames)",
        f"strip frames: {summary['strip_frames']} total_ms={summary['strip_total_ms']}",
        f"first alpha={summary['strip_first_alpha']:.3f} last alpha={summary['strip_last_alpha']:.3f}",
        f"alpha==1 frames: {summary['alpha_one_frames']}",
        f"first reset frame: {summary['reset_frame']} at {summary['reset_ms']} ms",
        f"reset recorded alpha: {summary['reset_alpha']} x={summary['reset_x']} y={summary['reset_y']}",
        f"a04 black max channel: {black_max} (0 means every pixel is pure black)",
        f"c01/c02 pause-freeze pixel diff: {pause_diff}",
        "GIF duration is derived from the sampled ms column, clamped to 10..80 ms;",
        "the game's alpha values are authoritative, not the GIF playback speed.",
        "All frames are setup states (arena combat / ledge walk), not a full playthrough.",
    ]
    (SHOT / "ANALYSIS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
