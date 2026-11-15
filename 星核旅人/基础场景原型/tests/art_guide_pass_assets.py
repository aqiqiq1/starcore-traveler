"""Verify the 2026-11-12 art pass assets and stage the pre-replacement backup.

This is an offline asset check only. It does not import, render or touch gameplay.

Usage (Python is always D:\\minic\\envs\\2024212971\\python.exe):
    python tests/art_guide_pass_assets.py --stage backup
    python tests/art_guide_pass_assets.py --stage verify
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE_ROOT = ROOT.parent / "项目归档"
BACKUP_ZIP = ARCHIVE_ROOT / "美术优化前运行资源_20261112.zip"
LOG_PATH = ROOT / "tests" / "logs" / "art_guide_pass_verify_20261112.log"
PASS_MANIFEST = ROOT / "assets" / "art_pass_20261112" / "manifest.json"
GUIDE_MANIFEST = ROOT / "assets" / "guide_echo_20261113" / "manifest.json"

# runtime path, derived path, manifest key
PAIRS = [
    (
        "assets/map/ruin_platform_tiles.png",
        "assets/art_pass_20261112/ruin_platform_tiles_warmgrey.png",
        "atlas",
    ),
    (
        "assets/level02_platform_v3/layer_platform_visual_640.png",
        "assets/art_pass_20261112/level02_platform_visual_highstep_trim_640.png",
        "visual",
    ),
    (
        "assets/level02_platform_v3/layer_platform_decor_640.png",
        "assets/art_pass_20261112/level02_platform_decor_seams_640.png",
        "decor",
    ),
]

GUIDE_PATH = "assets/guide_echo_20261113/guide_echo_idle_6f.png"
SOURCE_LAYERS = {
    "visual": ROOT.parent / "自制素材" / "第二关平台完整造型预览_V3" / "layer_platform_visual_640.png",
    "decor": ROOT.parent / "自制素材" / "第二关平台完整造型预览_V3" / "layer_platform_decor_640.png",
}

_checks: list[tuple[bool, str]] = []


def log(line: str = "") -> None:
    print(line)
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def check(condition: bool, message: str) -> bool:
    _checks.append((bool(condition), message))
    log(("PASS  " if condition else "FAIL  ") + message)
    return bool(condition)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def load_manifest() -> dict:
    return json.loads(PASS_MANIFEST.read_text(encoding="utf-8"))


def alpha_signature(image: Image.Image) -> bytes:
    return image.convert("RGBA").getchannel("A").tobytes()


def image_info(path: Path) -> tuple[Image.Image, str, tuple[int, int]]:
    image = Image.open(path)
    image.load()
    return image, image.mode, image.size


def verify_png_contracts(stage: str) -> None:
    manifest = load_manifest()
    log(f"== PNG contract checks ({stage}) ==")

    for runtime_rel, derived_rel, key in PAIRS:
        runtime = ROOT / runtime_rel
        derived = ROOT / derived_rel
        entry = manifest["derived"][key]
        source = manifest["sources"][key]
        check(runtime.exists(), f"{runtime_rel} exists")
        check(derived.exists(), f"{derived_rel} exists")
        if not runtime.exists() or not derived.exists():
            continue
        check(sha256(derived) == entry["sha256"].upper(), f"derived SHA matches manifest: {derived_rel}")
        if stage == "backup":
            check(sha256(runtime) == source["sha256"].upper(),
                  f"pre-replacement runtime SHA matches old source manifest: {runtime_rel}")
        expected_w, expected_h = entry["size"]
        for label, path in (("runtime", runtime), ("derived", derived)):
            image, mode, size = image_info(path)
            check(size == (expected_w, expected_h), f"{label} size {size} == {(expected_w, expected_h)}: {path.name}")
            check(mode == "RGBA", f"{label} mode RGBA (got {mode}): {path.name}")
            check("A" in image.getbands(), f"{label} has alpha channel: {path.name}")

    # The atlas must keep the exact alpha layout and 12 x 2 16 px grid.
    runtime_atlas, _, _ = image_info(ROOT / PAIRS[0][0])
    derived_atlas, _, _ = image_info(ROOT / PAIRS[0][1])
    check(alpha_signature(runtime_atlas) == alpha_signature(derived_atlas),
          "atlas alpha is byte-identical between old runtime and warm-grey derived")
    check(runtime_atlas.size == (192, 32), "atlas remains 192x32 = 12 x 2 tiles of 16 px")
    check(runtime_atlas.size[0] % 16 == 0 and runtime_atlas.size[1] % 16 == 0, "atlas grid is integral 16 px")

    # The high-step visual must be clear below the real 288 collision bottom.
    # Always inspect the approved derived asset, not the pre-replacement runtime.
    visual, _, _ = image_info(ROOT / PAIRS[1][1])
    rgba = visual.convert("RGBA")
    below = [rgba.getpixel((x, y))[3] for y in range(288, 300) for x in range(152, 208)]
    check(max(below) == 0, "left HighStep visual alpha is 0 for y>=288 under x152..207")
    check(any(rgba.getpixel((x, 287))[3] > 0 for x in range(152, 208)),
          "left HighStep still has visible pixels at y287 (collision bottom 288)")
    # The approved main-bridge and right-ledge slices are outside the derived
    # high-step diff and must still match their source pixels.
    source_visual = Image.open(SOURCE_LAYERS["visual"])
    source_visual.load()
    source_rgba = source_visual.convert("RGBA")
    outside = [
        (x, y)
        for y in range(264, 300)
        for x in range(232, 432)
        if not (152 <= x <= 207 and 285 <= y <= 299)
    ]
    check(all(rgba.getpixel(point) == source_rgba.getpixel(point) for point in outside),
          "main bridge/right ledge visual pixels are unchanged outside the HighStep trim")

    # The seam decor must carry neutral stone marks at the five real seam centres.
    decor, _, _ = image_info(ROOT / PAIRS[2][1])
    decor_rgba = decor.convert("RGBA")
    centers = [260, 284, 324, 348, 372]
    for center in centers:
        marked = 0
        for x in range(center - 2, center + 3):
            for y in range(266, 274):
                r, g, b, a = decor_rgba.getpixel((x, y))
                if a >= 90 and abs(r - b) <= 20 and r > 40:
                    marked += 1
        check(marked >= 3, f"neutral short groove visible at seam centre x={center} (marked={marked})")

    guide_manifest = json.loads(GUIDE_MANIFEST.read_text(encoding="utf-8"))
    guide = ROOT / GUIDE_PATH
    check(guide.exists(), f"{GUIDE_PATH} exists")
    if guide.exists():
        image, mode, size = image_info(guide)
        check(size == (288, 64), f"guide sheet remains 288x64 (got {size})")
        check(mode == "RGBA", f"guide sheet RGBA (got {mode})")
        check(sha256(guide) == guide_manifest["sheet"]["sha256"].upper(),
              "guide sheet SHA matches its manifest")
        check(guide_manifest["sheet"]["frame_size"] == [48, 64] and
              guide_manifest["sheet"]["frame_count"] == 6,
              "guide manifest frames are 6 x 48x64")
        # Actual visible content must stay inside its 48x64 frame and use the
        # declared top-left foot anchor (24,60), not a cropped frame.
        frames = guide_manifest["frames"]
        for frame in frames:
            left, top, right, bottom = frame["bbox"]
            check(left >= 0 and top >= 0 and right <= 48 and bottom <= 64,
                  f"guide frame {frame['frame']} bbox inside 48x64")
            check(frame["foot_anchor"] == [24, 60],
                  f"guide frame {frame['frame']} foot anchor is (24,60)")


def verify_backup_zip() -> None:
    manifest = load_manifest()
    log("== Backup ZIP checks ==")
    check(BACKUP_ZIP.exists(), f"backup ZIP exists: {BACKUP_ZIP}")
    if not BACKUP_ZIP.exists():
        return
    with zipfile.ZipFile(BACKUP_ZIP, "r") as archive:
        names = archive.namelist()
        for runtime_rel, _derived_rel, key in PAIRS:
            check(runtime_rel in names, f"ZIP keeps relative path: {runtime_rel}")
            if runtime_rel not in names:
                continue
            payload = archive.read(runtime_rel)
            actual = hashlib.sha256(payload).hexdigest().upper()
            expected = manifest["sources"][key]["sha256"].upper()
            check(actual == expected, f"ZIP entry hash matches pre-replacement runtime: {runtime_rel}")
        check(archive.testzip() is None, "ZIP CRC test passes")


def stage_backup() -> int:
    LOG_PATH.write_text("", encoding="utf-8")
    log("Art guide pass asset staging - 2026-11-12")
    log(f"Project: {ROOT}")
    verify_png_contracts("backup")
    if BACKUP_ZIP.exists():
        # Never overwrite an existing archive. If this exact pass already made
        # one, only re-verify it; operators must pick a new archive name for a
        # different baseline.
        log(f"KEPT existing archive (not overwritten): {BACKUP_ZIP}")
    else:
        ARCHIVE_ROOT.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(BACKUP_ZIP, "x", compression=zipfile.ZIP_DEFLATED) as archive:
            for runtime_rel, _derived_rel, _key in PAIRS:
                archive.write(ROOT / runtime_rel, arcname=runtime_rel)
        log(f"CREATED {BACKUP_ZIP}")
    verify_backup_zip()
    return finish("backup")


def stage_verify() -> int:
    log("== Runtime replacement checks ==")
    verify_png_contracts("verify")
    for runtime_rel, derived_rel, _key in PAIRS:
        check(sha256(ROOT / runtime_rel) == sha256(ROOT / derived_rel),
              f"runtime PNG is byte-identical to approved derived asset: {runtime_rel}")
    verify_backup_zip()
    # The read-only approved prompt layers must remain on disk untouched.
    manifest = load_manifest()
    for key in ("visual", "decor"):
        source = SOURCE_LAYERS[key]
        check(source.exists(), f"read-only approved source layer exists: {source}")
        if source.exists():
            check(sha256(source) == manifest["sources"][key]["sha256"].upper(),
                  f"approved source layer remains untouched: {source}")
    return finish("verify")


def finish(stage: str) -> int:
    passed = sum(1 for ok, _ in _checks if ok)
    failed = len(_checks) - passed
    log("")
    log(f"SUMMARY stage={stage} pass={passed} fail={failed}")
    log("RESULT: " + ("PASS" if failed == 0 else "FAIL"))
    return 0 if failed == 0 else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stage", choices=["backup", "verify"], default="verify")
    args = parser.parse_args()
    if args.stage == "backup":
        return stage_backup()
    return stage_verify()


if __name__ == "__main__":
    sys.exit(main())
