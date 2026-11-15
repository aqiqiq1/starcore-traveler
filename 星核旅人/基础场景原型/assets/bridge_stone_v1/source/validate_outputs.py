"""Structural checks for the formal bridge source and its CLI examples."""
from __future__ import annotations

import hashlib
import json
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, HERE)
import layout as L  # noqa: E402

EX = os.path.join(HERE, "examples")


def sha(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(65536), b""):
            h.update(b)
    return h.hexdigest()


def check_example(name, kind, left, right, top_rows):
    im = Image.open(os.path.join(EX, name)).convert("RGBA")
    w, h = im.size
    px = im.load()
    margin = 4 if kind == "ground" else (3 if kind == "deck" else 2)
    # top strip full width
    for y in range(top_rows):
        for x in range(w):
            assert px[x, y][3] == 255, ("top strip hole", name, x, y)
    # solid side edges must be fully present
    if left == "solid":
        for y in range(h):
            assert px[0, y][3] == 255, ("left solid hole", name, y)
    if right == "solid":
        for y in range(h):
            assert px[w - 1, y][3] == 255, ("right solid hole", name, y)
    # no interior holes; only outer margin of a broken side may clear
    for y in range(h):
        for x in range(w):
            if px[x, y][3] == 255:
                continue
            if left == "broken" and x < margin and y >= top_rows:
                continue
            if right == "broken" and x >= w - margin and y >= top_rows:
                continue
            raise AssertionError(("interior/edge hole", name, x, y))
    print(f"OK {name}: {w}x{h}, top {top_rows} full, no interior holes")


def main():
    cases = {
        "high_336x144.png": ("ground", "solid", "broken", 6),
        "high_336x144_both.png": ("ground", "broken", "broken", 6),
        "long_512x64.png": ("ground", "solid", "solid", 6),
        "long_1024x64.png": ("ground", "solid", "solid", 6),
        "level02_ground_640x40.png": ("ground", "solid", "solid", 6),
        "min_ground_32x32.png": ("ground", "broken", "broken", 6),
        "beam_56x8.png": ("deck", "solid", "solid", 2),
        "beam_56x8_broken.png": ("deck", "solid", "broken", 2),
        "beam_16x6.png": ("deck", "solid", "solid", 2),
        "beam_24x6.png": ("deck", "solid", "solid", 2),
        "beam_56x24.png": ("deck", "solid", "solid", 3),
        "beam_56x24_broken.png": ("deck", "solid", "broken", 3),
        "step_56x14.png": ("deck", "solid", "solid", 3),
        "min_beam_8x6.png": ("deck", "broken", "broken", 2),
        "pier_8x36.png": ("pier", "solid", "solid", 3),
        "pier_8x36_broken.png": ("pier", "solid", "broken", 3),
        "pier_8x24.png": ("pier", "solid", "solid", 3),
        "pier_16x36.png": ("pier", "solid", "solid", 3),
    }
    for name, (kind, left, right, top_rows) in cases.items():
        check_example(name, kind, left, right, top_rows)

    # atlas packing
    atlas = Image.open(os.path.join(HERE, "atlas.png")).convert("RGBA")
    assert atlas.size == L.ATLAS_SIZE
    used = []
    for name, (x, y, w, h) in L.MODULES.items():
        assert x >= 0 and y >= 0 and x + w <= atlas.width and y + h <= atlas.height, name
        for xx, yy, ww, hh in used:
            assert not (x < xx + ww and xx < x + w and y < yy + hh and yy < y + h), ("overlap", name)
        used.append((x, y, w, h))
    print(f"OK atlas {atlas.width}x{atlas.height}, {len(L.MODULES)} non-overlapping rects")

    # columns: same content as the approved preview basesquare copies
    prev = os.path.join(ROOT, "previews", "bridge_ground_sample_20261113", "art")
    src = os.path.join(ROOT, "assets", "doric_columns")
    src_manifest = json.load(open(os.path.join(src, "source_manifest.json"), encoding="utf-8"))
    src_hashes = {a["file"]: a["sha256"] for a in src_manifest["assets"]}
    for name, source in (
        ("doric_column_tall_basesquare.png", "doric_column_tall.png"),
        ("doric_column_broken_basesquare.png", "doric_column_broken.png"),
        ("doric_column_base_basesquare.png", "doric_column_base.png"),
    ):
        p = os.path.join(HERE, "..", "columns", name)
        assert os.path.exists(p)
        # columns live one level up; normalize
        p = os.path.abspath(os.path.join(HERE, "..", "columns", name))
        assert sha(p) == sha(os.path.join(prev, name)), ("column copy differs", name)
        assert sha(os.path.join(src, source)) == src_hashes[source], ("source changed", source)
        i = Image.open(p).convert("RGBA")
        s = Image.open(os.path.join(src, source)).convert("RGBA")
        b = i.height - 9
        for y in range(b):
            for x in range(i.width):
                assert i.getpixel((x, y)) == s.getpixel((x, y)), ("upper changed", name, x, y)
        for x in range(9, 43):
            assert i.getpixel((x, i.height - 1))[3] == 255
        print(f"OK column {name}: upper unchanged, flat contact x9..42, copy hash matches")

    print("validator done")


if __name__ == "__main__":
    main()
