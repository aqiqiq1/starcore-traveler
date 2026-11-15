#!/usr/bin/env python3
"""Export the approved V7 cloud-ruins background without resampling.

Source (read-only): 星核旅人/自制素材/云海遗迹背景概念示意/background_only_v7.png
  - 1280x720 RGB, i.e. the approved 640x360 logical image shown with NEAREST 2x.
  - Every 2x2 block must be identical before extraction.
Output: assets/backgrounds/cloud_ruins_v7.png
  - 640x360 RGB, top-left pixel of each 2x2 block; no scaling, filtering or tint.
The script also re-expands the result with NEAREST 2x and compares every pixel
against the source, then writes assets/backgrounds/source_manifest.json.

Run with the project Python only:
  D:\\minic\\envs\\2024212971\\python.exe tools/export_background_v7.py
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT_ROOT = Path(__file__).resolve().parents[1]
WORKSPACE_ROOT = PROJECT_ROOT.parent
SOURCE_PATH = WORKSPACE_ROOT / "自制素材" / "云海遗迹背景概念示意" / "background_only_v7.png"
OUTPUT_DIR = PROJECT_ROOT / "assets" / "backgrounds"
OUTPUT_PATH = OUTPUT_DIR / "cloud_ruins_v7.png"
MANIFEST_PATH = OUTPUT_DIR / "source_manifest.json"

EXPECTED_SOURCE_SHA256 = "2d65a27d432ce60d8562c71cf754049d49a106d08e63348d78cb08f4c8387aae"
SOURCE_SIZE = (1280, 720)
LOGICAL_SIZE = (640, 360)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> None:
    if not SOURCE_PATH.is_file():
        fail(f"approved V7 source is missing: {SOURCE_PATH}")

    source_sha = sha256_file(SOURCE_PATH)
    if source_sha != EXPECTED_SOURCE_SHA256:
        fail(
            "approved V7 source SHA256 changed; refusing to derive a new asset "
            f"(expected {EXPECTED_SOURCE_SHA256}, got {source_sha})"
        )

    with Image.open(SOURCE_PATH) as image:
        image.load()
        if image.mode != "RGB":
            fail(f"approved V7 source must stay RGB; got {image.mode}")
        if image.size != SOURCE_SIZE:
            fail(f"approved V7 source must be {SOURCE_SIZE}; got {image.size}")
        source = np.asarray(image, dtype=np.uint8).copy()

    # The source is the approved 640x360 image at NEAREST 2x. Do not accept a
    # source that would silently lose per-pixel detail when pulled back down.
    quads = (
        source[0::2, 0::2],
        source[1::2, 0::2],
        source[0::2, 1::2],
        source[1::2, 1::2],
    )
    identical = all(np.array_equal(quads[0], block) for block in quads[1:])
    mismatch_pixels = int(
        np.count_nonzero(quads[0] != quads[1])
        + np.count_nonzero(quads[0] != quads[2])
        + np.count_nonzero(quads[0] != quads[3])
    )
    if not identical:
        fail(
            "source 2x2 blocks are not identical; refusing to discard detail "
            f"({mismatch_pixels} differing channel samples)"
        )

    runtime = np.ascontiguousarray(quads[0])
    if runtime.shape != (LOGICAL_SIZE[1], LOGICAL_SIZE[0], 3):
        fail(f"extracted runtime image has unexpected shape {runtime.shape}")

    expanded = np.repeat(np.repeat(runtime, 2, axis=0), 2, axis=1)
    if not np.array_equal(expanded, source):
        fail("NEAREST 2x re-expansion of the extracted image differs from source")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray(runtime, mode="RGB").save(
        OUTPUT_PATH,
        format="PNG",
        compress_level=9,
        optimize=False,
    )

    with Image.open(OUTPUT_PATH) as written:
        written.load()
        written_array = np.asarray(written, dtype=np.uint8)
    if written.mode != "RGB" or written_array.shape != runtime.shape:
        fail("written PNG changed mode or dimensions")
    if not np.array_equal(written_array, runtime):
        fail("PNG round-trip changed pixels")
    if not np.array_equal(
        np.repeat(np.repeat(written_array, 2, axis=0), 2, axis=1), source
    ):
        fail("written PNG re-expanded with NEAREST 2x differs from source")

    runtime_sha = sha256_file(OUTPUT_PATH)
    manifest = {
        "version": "v7",
        "status": "static full-frame background; integrated in scenes/level_01.tscn",
        "source": "自制素材/云海遗迹背景概念示意/background_only_v7.png",
        "source_sha256": source_sha,
        "source_size": list(SOURCE_SIZE),
        "source_mode": "RGB",
        "runtime": "assets/backgrounds/cloud_ruins_v7.png",
        "runtime_sha256": runtime_sha,
        "runtime_size": list(LOGICAL_SIZE),
        "runtime_mode": "RGB",
        "pixel_filter": "nearest",
        "display_scale": "2x NEAREST from 640x360 logical pixels",
        "extraction": (
            "top-left pixel of each 2x2 block; no resampling, redraw, tint, "
            "blur, sharpen or color management"
        ),
        "generator": "tools/export_background_v7.py",
        "verification": {
            "source_2x2_blocks_identical": True,
            "source_2x2_mismatch_channel_samples": 0,
            "runtime_png_round_trip_equal": True,
            "runtime_nearest_2x_equals_source": True,
            "logged_source_sha256": source_sha,
            "logged_runtime_sha256": runtime_sha,
        },
    }
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    print(f"source:   {SOURCE_PATH}")
    print(f"source:   {SOURCE_SIZE[0]}x{SOURCE_SIZE[1]} RGB sha256={source_sha}")
    print(f"runtime:  {OUTPUT_PATH}")
    print(f"runtime:  {LOGICAL_SIZE[0]}x{LOGICAL_SIZE[1]} RGB sha256={runtime_sha}")
    print("check:    all 2x2 source blocks identical (0 mismatch channel samples)")
    print("check:    runtime PNG round-trip exact")
    print("check:    runtime re-expanded NEAREST 2x equals source, every pixel")
    print(f"manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
