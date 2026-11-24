"""Pixel audit for the 2026-11-19 hold-to-skip bar screenshots.

Run with the project Python:
  D:\\minic\\envs\\2024212971\\python.exe tests/skip_progress_20261119/verify_shots.py

Checks the saved 640x360 PNGs for:
  - the exact 96x6 track rectangle and its #739e9f 1 px border;
  - gold #f4cd63 fill starting at x=529 and growing with progress;
  - the muted 12 px "跳过" label pixels left of x=528;
  - no bar/fill residue in the after-skip frames.

This reads the already-captured images only; it does not run Godot.
"""

from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
GOLD = (244, 205, 99)
BORDER = (115, 158, 159)
MUTED = (164, 179, 190)
EXPECTED_WIDTH = {20: (19, 19), 40: (38, 38), 60: (56, 57)}

failures = []


def close(pixel, target, tolerance=3):
    return all(abs(int(a) - int(b)) <= tolerance for a, b in zip(pixel[:3], target))


def audit(name, progress):
    image = Image.open(HERE / name).convert("RGB")
    if image.size != (640, 360):
        failures.append(f"{name}: size {image.size} != 640x360")
        return

    gold = [
        (x, y)
        for y in range(330, 350)
        for x in range(500, 640)
        if close(image.getpixel((x, y)), GOLD)
    ]
    if not gold:
        failures.append(f"{name}: no gold fill found")
        return
    xs = [p[0] for p in gold]
    ys = [p[1] for p in gold]
    fill_left, fill_right = min(xs), max(xs)
    fill_top, fill_bottom = min(ys), max(ys)
    width = fill_right - fill_left + 1

    if fill_left != 529:
        failures.append(f"{name}: fill starts at x={fill_left}, expected 529")
    if fill_top != 337 or fill_bottom != 340:
        failures.append(f"{name}: fill rows {fill_top}..{fill_bottom}, expected 337..340")
    expected = EXPECTED_WIDTH[progress]
    if width not in expected:
        failures.append(f"{name}: fill width {width}, expected {expected[0]}..{expected[-1]}")

    border = [
        (x, y)
        for y in range(335, 343)
        for x in range(527, 626)
        if close(image.getpixel((x, y)), BORDER, 2)
    ]
    border_xs = sorted({p[0] for p in border})
    border_ys = sorted({p[1] for p in border})
    if not border:
        failures.append(f"{name}: no #739e9f border found")
    elif border_xs[0] != 528 or border_xs[-1] != 623:
        failures.append(f"{name}: border x {border_xs[0]}..{border_xs[-1]}, expected 528..623")
    elif border_ys[0] != 336 or border_ys[-1] != 341:
        failures.append(f"{name}: border y {border_ys[0]}..{border_ys[-1]}, expected 336..341")

    label_pixels = [
        (x, y)
        for y in range(325, 355)
        for x in range(480, 528)
        if close(image.getpixel((x, y)), MUTED, 24)
    ]
    if len(label_pixels) < 20:
        failures.append(f"{name}: too few label pixels left of the bar ({len(label_pixels)})")

    print(
        f"{name}: {image.size[0]}x{image.size[1]} gold x={fill_left}..{fill_right} "
        f"width={width} rows={fill_top}..{fill_bottom} border={border_xs[0] if border_xs else '-'}"
        f"..{border_xs[-1] if border_xs else '-'} label_pixels={len(label_pixels)}"
    )


def audit_hidden(name):
    image = Image.open(HERE / name).convert("RGB")
    if image.size != (640, 360):
        failures.append(f"{name}: size {image.size} != 640x360")
        return
    gold_in_bar = sum(
        1
        for y in range(336, 342)
        for x in range(528, 624)
        if close(image.getpixel((x, y)), GOLD, 8)
    )
    border_in_bar = sum(
        1
        for y in range(336, 342)
        for x in range(528, 624)
        if close(image.getpixel((x, y)), BORDER, 2)
    )
    if gold_in_bar or border_in_bar:
        failures.append(
            f"{name}: residue gold={gold_in_bar} border={border_in_bar} inside the bar rect"
        )
    print(f"{name}: {image.size[0]}x{image.size[1]} gold_in_bar={gold_in_bar} border_in_bar={border_in_bar}")


for prefix in ("l1_opening", "l3_cinematic"):
    for progress in (20, 40, 60):
        audit(f"{prefix}_hold_{progress:03d}.png", progress)
    audit_hidden(f"{prefix}_after_skip_hidden.png")

print("PIXEL_AUDIT_FAIL" if failures else "PIXEL_AUDIT_OK")
for failure in failures:
    print("FAIL:", failure)
raise SystemExit(1 if failures else 0)
