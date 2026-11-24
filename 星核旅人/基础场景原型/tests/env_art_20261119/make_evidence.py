"""Before/after evidence for tests/env_art_20261119.

Run with the project Python:
  D:\\minic\\envs\\2024212971\\python.exe tests\\env_art_20261119\\make_evidence.py

Reads the 640x360 PNGs produced by capture_env_art.gd from before/ and after/,
prints per-station pixel-diff statistics (L1 must be exactly zero), and writes
side-by-side comparisons plus 4x nearest-neighbour crop sheets into compare/.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageStat

ROOT = Path(__file__).resolve().parent
COMPARE = ROOT / "compare"
STATIONS = [
    ("l1_start", "L1 start", True),
    ("l1_high", "L1 high platform", True),
    ("l2_start", "L2 start bay", False),
    ("l2_lowcorridor", "L2 low corridor roof", False),
    ("l2_linked", "L2 linked bay high platform", False),
    ("l3_start", "L3 start", False),
    ("l3_gate", "L3 gate front", False),
]

# (name, station, source rect, zoom). Station-local screen coordinates:
# l2_start view = world 0..640; l2_lowcorridor = world-200; l2_linked = world-830.
EDGE_CROPS = [
    ("l2_ground_start_4x", "l2_start", (0, 300, 160, 60), 4),
    ("l2_ground_chip_4x", "l2_start", (50, 300, 200, 60), 4),
    ("l2_ground_mid_4x", "l2_start", (400, 300, 200, 60), 4),
    ("l2_roof_left_4x", "l2_lowcorridor", (244, 246, 140, 78), 4),
    ("l2_roof_right_4x", "l2_lowcorridor", (470, 246, 150, 78), 4),
    ("l2_wall_lip_4x", "l2_linked", (192, 216, 136, 96), 4),
    ("l2_wall_right_4x", "l2_linked", (360, 216, 140, 96), 4),
]
BG_CROPS = [
    ("l2_far_arch_4x", "l2_start", (150, 128, 292, 164), 4),
    ("l2_sea_rock_4x", "l2_start", (180, 180, 264, 144), 4),
    ("l2_horizon_haze_4x", "l2_start", (200, 252, 240, 40), 4),
    ("l3_far_bridge_4x", "l3_gate", (0, 120, 300, 170), 4),
]


def _font(size: int):
    for candidate in ("C:/Windows/Fonts/arial.ttf", "C:/Windows/Fonts/segoeui.ttf"):
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def _label(draw: ImageDraw.ImageDraw, xy, text, font):
    draw.rectangle((xy[0] - 2, xy[1] - 1, xy[0] + 8 + int(font.size * 0.6) * len(text), xy[1] + font.size + 2), fill=(16, 18, 22))
    draw.text(xy, text, fill=(232, 238, 240), font=font)


def _load(tag: str, station: str) -> Image.Image | None:
    path = ROOT / tag / f"{station}_clean.png"
    if not path.exists():
        return None
    return Image.open(path).convert("RGB")


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _side_by_side(name: str, station: str, before: Image.Image, after: Image.Image, font) -> None:
    w, h = before.size
    out = Image.new("RGB", (w * 2, h + 22), (16, 18, 22))
    out.paste(before, (0, 22))
    out.paste(after, (w, 22))
    draw = ImageDraw.Draw(out)
    draw.text((8, 4), f"{name}  BEFORE", fill=(232, 238, 240), font=font)
    draw.text((w + 8, 4), "AFTER", fill=(232, 238, 240), font=font)
    out.save(COMPARE / f"{station}_before_after.png")


def _crop_sheet(name: str, station: str, rect, zoom: int, font) -> None:
    before = _load("before", station)
    after = _load("after", station)
    if before is None or after is None:
        return
    box = (rect[0], rect[1], rect[0] + rect[2], rect[1] + rect[3])
    bw = before.crop(box).resize((rect[2] * zoom, rect[3] * zoom), Image.NEAREST)
    aw = after.crop(box).resize((rect[2] * zoom, rect[3] * zoom), Image.NEAREST)
    out = Image.new("RGB", (bw.width * 2, bw.height + 22), (16, 18, 22))
    out.paste(bw, (0, 22))
    out.paste(aw, (bw.width, 22))
    draw = ImageDraw.Draw(out)
    draw.text((8, 4), f"{name} {zoom}x  BEFORE", fill=(232, 238, 240), font=font)
    draw.text((bw.width + 8, 4), "AFTER", fill=(232, 238, 240), font=font)
    out.save(COMPARE / f"{name}_before_after.png")


def _clearance_sheet(font) -> None:
    path = ROOT / "after" / "l2_edge_clearance_full.png"
    if not path.exists():
        return
    img = Image.open(path).convert("RGB")
    box = (0, 300, 300, 360)
    zoom = 6
    crop = img.crop(box)
    crop = crop.resize((crop.width * zoom, crop.height * zoom), Image.NEAREST)
    out = Image.new("RGB", (crop.width, crop.height + 22), (16, 18, 22))
    out.paste(crop, (0, 22))
    draw = ImageDraw.Draw(out)
    draw.text((8, 4), "L2 edge clearance 6x  AFTER: core at moss x=32, player stands on chip x=96", fill=(232, 238, 240), font=font)
    draw.text((32 * zoom + 4, 24), "core", fill=(240, 220, 120), font=font)
    draw.text((96 * zoom - 18, 24), "player", fill=(240, 220, 120), font=font)
    out.save(COMPARE / "l2_edge_clearance_6x.png")


def _overview_sheet(font) -> None:
    rows = [
        ("L2 start bay", "l2_start"),
        ("L2 linked bay high platform", "l2_linked"),
        ("L3 gate front", "l3_gate"),
    ]
    w, h = 640, 360
    gap = 22
    out = Image.new("RGB", (w * 2, (h + gap) * len(rows)), (16, 18, 22))
    draw = ImageDraw.Draw(out)
    for index, (label, station) in enumerate(rows):
        before = _load("before", station)
        after = _load("after", station)
        if before is None or after is None:
            continue
        y = index * (h + gap)
        out.paste(before, (0, y + gap))
        out.paste(after, (w, y + gap))
        draw.text((8, y + 4), f"{label}  BEFORE", fill=(232, 238, 240), font=font)
        draw.text((w + 8, y + 4), "AFTER", fill=(232, 238, 240), font=font)
    out.save(COMPARE / "l2_l3_depth_overview_1x.png")


def main() -> int:
    COMPARE.mkdir(parents=True, exist_ok=True)
    font = _font(14)
    lines: list[str] = []
    failures: list[str] = []

    for station, label, must_match in STATIONS:
        before = _load("before", station)
        after = _load("after", station)
        if before is None or after is None:
            lines.append(f"{station}: SKIP (before={before is not None} after={after is not None})")
            continue
        _side_by_side(label, station, before, after, font)
        diff = ImageChops.difference(before, after)
        bbox = diff.getbbox()
        count = 0
        peak = 0
        for pixel in diff.getdata():
            if pixel != (0, 0, 0):
                count += 1
                peak = max(peak, *pixel)
        total = before.width * before.height
        lines.append(
            f"{station}: diff_px={count}/{total} ({count / total * 100:.2f}%) "
            f"peak={peak} bbox={bbox}"
        )
        # Split the frame at the ground line. L2 ground decoration lives only
        # below y=320; the background grade lives above it. Reporting them
        # separately keeps a local decor mark from being read as a global shift.
        for region_name, box in (("bg", (0, 0, 640, 320)), ("ground", (0, 320, 640, 360))):
            region = diff.crop(box)
            region_count = sum(1 for p in region.getdata() if p != (0, 0, 0))
            region_peak = max(max(p) for p in region.getdata())
            stat = ImageStat.Stat(region)
            mean = sum(stat.mean) / 3.0
            lines.append(
                f"  {region_name}: diff_px={region_count} peak={region_peak} mean_abs={mean:.2f}"
            )
        if count:
            amp = diff.point(lambda v: min(255, v * 4))
            amp.save(COMPARE / f"{station}_diff4x.png")
        if must_match and count != 0:
            failures.append(f"{station}: expected 0 differing pixels, got {count} (peak {peak})")

    for name, station, rect, zoom in EDGE_CROPS + BG_CROPS:
        _crop_sheet(name, station, rect, zoom, font)
    _clearance_sheet(font)
    _overview_sheet(font)

    for tag in ("before", "after"):
        path = ROOT / tag / "l1_start_clean.png"
        if path.exists():
            lines.append(f"sha256 {tag} l1_start_clean: {_sha(path)}")
        path = ROOT / tag / "ds03_default.png"
        if path.exists():
            lines.append(f"sha256 {tag} ds03_default: {_sha(path)}")

    text = "\n".join(lines) + "\n"
    (ROOT / "diff.log").write_text(text, encoding="utf-8")
    print(text)
    if failures:
        print("L1_PROTECTION_FAIL")
        for failure in failures:
            print(" ", failure)
        return 1
    print("EVIDENCE_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
