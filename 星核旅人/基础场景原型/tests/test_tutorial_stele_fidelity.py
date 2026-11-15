"""Pixel-fidelity check for the tutorial-stele runtime art.

Run with the project Python:
  D:\\minic\\envs\\2024212971\\python.exe tests/test_tutorial_stele_fidelity.py

It imports the approved concept script directly and compares the shipped PNGs:
  * grey / gold / cyan references are byte-for-byte Image data at band_y=26;
  * the groove mask is the concept groove_floor();
  * every animation frame keeps the exact grey shell and only changes pixels
    inside that mask;
  * the sheet is 64 frames at 26x52 and the band actually travels downward.

This is a generator-art check, not a Godot engine test.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

from PIL import Image, ImageChops

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT.parent
CONCEPT_SCRIPT = ROOT / "自制素材" / "提示石碑概念示意" / "draw_concept.py"
ASSETS = PROJECT / "assets" / "tutorial_stele"

FRAME_COUNT = 64
FRAME_SIZE = (26, 52)


def load_concept():
    spec = importlib.util.spec_from_file_location("stele_concept_test", CONCEPT_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_rgba(name: str) -> Image.Image:
    return Image.open(ASSETS / name).convert("RGBA")


def equal(a: Image.Image, b: Image.Image) -> bool:
    return ImageChops.difference(a.convert("RGBA"), b.convert("RGBA")).getbbox() is None


def main() -> int:
    passed = 0
    failed = 0
    lines: list[str] = []

    def check(condition: bool, label: str, detail: str = "") -> None:
        nonlocal passed, failed
        if condition:
            passed += 1
            lines.append(f"[PASS] {label}" + (f"  ({detail})" if detail else ""))
        else:
            failed += 1
            lines.append(f"[FAIL] {label}" + (f"  ({detail})" if detail else ""))

    concept = load_concept()
    grey = load_rgba("tutorial_stele_grey.png")
    gold = load_rgba("tutorial_stele_gold.png")
    cyan = load_rgba("tutorial_stele_cyan.png")
    mask = concept.groove_floor()
    sheet = load_rgba("tutorial_stele_frames.png")

    check(concept.SIZE == FRAME_SIZE, "concept stone size is 26x52", str(concept.SIZE))
    check(equal(grey, concept.stone("grey", 26)), "grey reference equals concept stone('grey', 26)")
    check(equal(gold, concept.stone("gold", 26)), "gold reference equals concept stone('gold', 26)")
    check(equal(cyan, concept.stone("cyan", 26)), "cyan reference equals concept stone('cyan', 26)")
    check(
        len({grey.getchannel("A").tobytes(), gold.getchannel("A").tobytes(), cyan.getchannel("A").tobytes()}) == 1,
        "all three references share one silhouette",
    )

    widths = [sum(mask.getpixel((x, y)) > 0 for x in range(26)) for y in range(12, 42)]
    check(widths[:9] == [5] * 9, "upper groove stays 5 px", str(widths[:9]))
    check(widths[9:12] == [4] * 3, "groove eases 5 -> 4", str(widths[9:12]))
    check(widths[12:17] == [3] * 5, "waist is 3 px", str(widths[12:17]))
    check(widths[17:20] == [4] * 3, "groove eases 4 -> 5", str(widths[17:20]))
    check(widths[20:] == [5] * 10, "lower groove stays 5 px", str(widths[20:]))

    # Outside the groove both immediately-readable reference lights are exact
    # grey; only the floor can change.
    outside = mask.point(lambda value: 0 if value else 255)
    for name, image in (("gold", gold), ("cyan", cyan)):
        diff = ImageChops.difference(image, grey)
        outside_nonzero = ImageChops.multiply(diff.convert("L"), outside).getbbox()
        check(outside_nonzero is None, f"{name} light is confined to the groove")

    check(sheet.width == FRAME_SIZE[0] * FRAME_COUNT and sheet.height == FRAME_SIZE[1], "sheet is 64 x 26x52", str(sheet.size))
    frame_16 = sheet.crop((16 * 26, 0, 17 * 26, 52))
    frame_48 = sheet.crop((48 * 26, 0, 49 * 26, 52))
    check(equal(frame_16, concept.stone("gold", 26)), "animation frame 16 equals the approved gold band_y=26 reference")
    check(equal(frame_48, concept.stone("cyan", 26)), "animation frame 48 equals the approved cyan band_y=26 reference")

    centres: list[int | None] = []
    shell_ok = True
    lit_ok = True
    for index in range(FRAME_COUNT):
        frame = sheet.crop((index * 26, 0, (index + 1) * 26, 52))
        if ImageChops.difference(frame, grey).getbbox() is not None:
            # Difference must be restricted to mask pixels.
            for y in range(52):
                for x in range(26):
                    if frame.getpixel((x, y)) != grey.getpixel((x, y)) and mask.getpixel((x, y)) == 0:
                        shell_ok = False
        # Strongest changed row marks the travelling band.
        best_row = -1
        best_score = 0
        for y in range(9, 44):
            score = 0
            for x in range(26):
                if mask.getpixel((x, y)) == 0:
                    continue
                a = frame.getpixel((x, y))
                b = grey.getpixel((x, y))
                score += abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])
            if score > best_score:
                best_score = score
                best_row = y
        centres.append(best_row if best_score > 400 else None)

    check(shell_ok, "all 64 animation frames leave every non-groove pixel unchanged")
    check(all(any(mask.getpixel((x, y)) > 0 for x in range(26)) for y in range(9, 44)), "groove exists across the animated span")

    runs: list[list[int]] = []
    run: list[int] = []
    for centre in centres:
        if centre is None:
            if run:
                runs.append(run)
                run = []
        else:
            run.append(centre)
    if run:
        runs.append(run)
    check(len(runs) == 2, "two band passes are visible in the 8 s loop", str([len(r) for r in runs]))
    check(all(any(b < a for a, b in zip(r, r[1:])) is False for r in runs), "each band pass only moves downward", str(runs))
    check(all(r[0] <= 14 and r[-1] >= 37 for r in runs), "each pass covers the full groove", str(runs))

    # The two held passes keep the approved hues; frame 16/48 above prove the
    # visible band is exactly one of them at the band_y=26 checkpoint.
    f0 = sheet.crop((0, 0, 26, 52)).getpixel((12, 26))
    f48 = sheet.crop((48 * 26, 0, 49 * 26, 52)).getpixel((12, 26))
    check(f0[0] > f0[2], "loop start has a gold-dominant groove", str(f0))
    check(f48[2] > f48[0], "cyan pass has a cyan-dominant groove", str(f48))

    print("\n".join(lines))
    print()
    print(f"FIDELITY_SUMMARY pass={passed} fail={failed}")
    print("RESULT: " + ("PASS" if failed == 0 else "FAIL"))
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
