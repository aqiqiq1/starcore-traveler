"""Offline material-fidelity check for the checkpoint / exit warm-stone revision.

Reconstructs the pre-revision art in memory by running the same drawing
functions with the documented old green-grey stone palette, then proves for all
four source PNGs that:

* alpha is unchanged pixel for pixel;
* every changed pixel is exactly an old stone RGB -> its mapped Doric tone;
* every non-stone pixel (moss/leaf/cyan/ice/gold, hard-coded inactive glow,
  transparent RGB) is byte-for-byte unchanged;
* every mapped tone exists in the shipped doric_column_tall.png palette;
* each source PNG is byte-identical to its runtime copy.

The check is reproducible from the project alone. If the coordinator's
read-only baseline directory is present, it is also compared directly.

Run with:
  D:\\minic\\envs\\2024212971\\python.exe tests/verify_checkpoint_exit_stone_palette.py
"""

from __future__ import annotations

import hashlib
import importlib.util
import sys
from datetime import datetime
from pathlib import Path

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
CONCEPT = PROJECT.parent / "自制素材" / "恢复点与通关门概念示意"
SOURCE_SCRIPT = CONCEPT / "generate_preview.py"
DORIC = PROJECT / "assets/doric_columns" / "doric_column_tall.png"
RUNTIME = PROJECT / "assets" / "checkpoint_exit"
LOG_DIR = PROJECT / "tests" / "logs"
BASELINE_DEFAULT = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\stone-palette-baseline-8dc3f0f87ba94d4c93ebb769662c18db"
)

# The pre-revision palette from generate_preview.py before the warm-stone pass.
OLD_STONE = {
    "out": (0x48, 0x4C, 0x53),
    "dark": (0x66, 0x69, 0x6C),
    "shade": (0x7F, 0x81, 0x80),
    "stone": (0x9D, 0x9E, 0x95),
    "mid": (0xAF, 0xB0, 0xA4),
    "light": (0xC6, 0xC7, 0xB8),
    "glint": (0xD9, 0xDA, 0xCA),
    "groove": (0x62, 0x6C, 0x70),
}
# Ordered by material role / ascending value, sampled from doric_column_tall.png.
NEW_STONE = {
    "out": (66, 55, 62),       # EDGE
    "dark": (89, 74, 81),      # DARK
    "groove": (103, 87, 93),   # recess
    "shade": (113, 96, 100),   # SHADE
    "stone": (143, 128, 126),  # MID
    "mid": (160, 145, 138),    # lip
    "light": (174, 161, 151),  # lit
    "glint": (181, 169, 158),  # TOP
}
ROLE_ORDER = list(NEW_STONE)
FILES = [
    "checkpoint_inactive.png",
    "checkpoint_active.png",
    "exit_open.png",
    "exit_completed.png",
]

lines: list[str] = []
passed = 0
failed = 0


def log(text: str = "") -> None:
    lines.append(text)
    print(text)


def check(condition: bool, label: str, detail: str = "") -> None:
    global passed, failed
    passed += 1
    if not condition:
        failed += 1
    log(f"[{'PASS' if condition else 'FAIL'}] {label}" + (f"  ({detail})" if detail else ""))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def load_generator():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("checkpoint_exit_preview", SOURCE_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    baseline = Path(sys.argv[1]) if len(sys.argv) > 1 else BASELINE_DEFAULT
    log("Star Core Traveler - checkpoint / exit warm-stone material fidelity")
    log("Godot-independent Pillow check; no image is written.")
    log(f"source script: {SOURCE_SCRIPT}")
    log(f"doric reference: {DORIC}")
    log("")

    gen = load_generator()
    check(gen.P is not None, "concept generator imports")
    for role in ROLE_ORDER:
        actual = gen.P[role]
        expected = "#%02x%02x%02x" % NEW_STONE[role]
        check(actual.lower() == expected, f"generator P[{role}] is the documented Doric tone", f"{actual} == {expected}")
    for key in ("moss", "leaf", "cyan", "ice", "gold"):
        check(key in gen.P, f"non-stone accent P[{key}] is still defined")

    # Reconstruct the exact pre-revision pixels with the same drawing code.
    new_p = dict(gen.P)
    old_p = dict(gen.P)
    for role, rgb in OLD_STONE.items():
        old_p[role] = "#%02x%02x%02x" % rgb
    gen.P = old_p
    old_images = {
        "checkpoint_inactive.png": gen.checkpoint(False),
        "checkpoint_active.png": gen.checkpoint(True),
        "exit_open.png": gen.gate(False),
        "exit_completed.png": gen.gate(True),
    }
    gen.P = new_p
    new_images = {
        "checkpoint_inactive.png": gen.checkpoint(False),
        "checkpoint_active.png": gen.checkpoint(True),
        "exit_open.png": gen.gate(False),
        "exit_completed.png": gen.gate(True),
    }
    check(True, "pre-revision art reconstructed from the same geometry functions")

    if baseline.is_dir():
        for name in FILES:
            old = old_images[name]
            base = rgba(baseline / name)
            check(old.size == base.size and old.tobytes() == base.tobytes(),
                  f"reconstructed old pixels match coordinator baseline: {name}")
    else:
        log(f"[INFO] baseline directory absent, skipped direct baseline compare: {baseline}")

    doric = rgba(DORIC)
    if hasattr(doric, "get_flattened_data"):
        doric_pixels = set(doric.get_flattened_data())
    else:
        doric_pixels = set(doric.getdata())
    for role in ROLE_ORDER:
        rgb = NEW_STONE[role]
        check((*rgb, 255) in doric_pixels,
              f"target tone comes from doric_column_tall.png: {role}",
              str(rgb))
    lum = [0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2] for rgb in NEW_STONE.values()]
    check(all(a < b for a, b in zip(lum, lum[1:])),
          "all eight stone roles keep ascending luminance", ", ".join(f"{v:.1f}" for v in lum))

    old_by_rgb = {rgb: role for role, rgb in OLD_STONE.items()}
    for name in FILES:
        log("")
        log(f"-- {name} --")
        source = CONCEPT / name
        runtime = RUNTIME / name
        check(source.is_file() and runtime.is_file(), f"source and runtime PNG exist: {name}")
        if not (source.is_file() and runtime.is_file()):
            continue
        new = rgba(source)
        old = old_images[name]
        check(new.size == old.size, f"canvas size unchanged: {name}", str(new.size))
        check(new.tobytes() == new_images[name].tobytes(),
              f"source PNG matches the current generator and documented palette: {name}")
        check(new.getchannel("A").tobytes() == old.getchannel("A").tobytes(),
              f"alpha mask unchanged pixel for pixel: {name}")

        role_counts = {role: 0 for role in ROLE_ORDER}
        preserved = 0
        mismatches: list[str] = []
        new_px = new.load()
        old_px = old.load()
        for y in range(new.height):
            for x in range(new.width):
                old_pixel = old_px[x, y]
                new_pixel = new_px[x, y]
                role = old_by_rgb.get(old_pixel[:3]) if old_pixel[3] else None
                if role is None:
                    if new_pixel != old_pixel:
                        if len(mismatches) < 3:
                            mismatches.append(f"({x},{y}) {old_pixel}->{new_pixel}")
                    else:
                        preserved += 1
                    continue
                role_counts[role] += 1
                expected = (*NEW_STONE[role], old_pixel[3])
                if new_pixel != expected and len(mismatches) < 3:
                    mismatches.append(f"({x},{y}) {old_pixel}->{new_pixel}, expected {expected}")
        check(not mismatches, f"only documented stone RGB substitutions: {name}", "; ".join(mismatches))
        check(all(count > 0 for count in role_counts.values()),
              f"all eight Doric tones visible: {name}",
              ", ".join(f"{role}={role_counts[role]}" for role in ROLE_ORDER))
        check(sum(role_counts.values()) > 0, f"stone pixels were remapped: {name}",
              f"{sum(role_counts.values())} changed, {preserved} non-stone pixels preserved")
        check(source.read_bytes() == runtime.read_bytes(),
              f"runtime copy is byte-identical to source: {name}")
        log(f"       sha256 {sha256(source)}")
        log(f"       remap " + ", ".join(f"{role}:{role_counts[role]}" for role in ROLE_ORDER))

    log("")
    log(f"MATERIAL_SUMMARY pass={passed} fail={failed}")
    log("RESULT: " + ("PASS" if failed == 0 else "FAIL"))
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_path = LOG_DIR / f"checkpoint_exit_stone_palette_{stamp}.log"
    log_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"LOG_FILE {log_path}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
