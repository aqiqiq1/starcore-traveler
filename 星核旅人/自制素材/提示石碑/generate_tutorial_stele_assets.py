"""Generate runtime assets for the approved tutorial-stele concept.

The only geometry source is the user-approved concept script
``自制素材/提示石碑概念示意/draw_concept.py``.  This generator imports that file
and calls its own ``stone()`` / ``groove_floor()``; it does not redraw, resize,
re-colour or crop the 26x52 stone silhouette.

Outputs live in ``基础场景原型/assets/tutorial_stele/``:

* tutorial_stele_grey.png          exact stone('grey', 26)
* tutorial_stele_gold.png          exact stone('gold', 26)
* tutorial_stele_cyan.png          exact stone('cyan', 26)
* tutorial_stele_groove_mask.png   exact groove_floor() mask
* tutorial_stele_frames.png        64 x 26x52 animation frames
* tutorial_stele_manifest.json     generation facts + hashes + validation

The animated sheet is pre-composited from the concept function.  Every frame
keeps the identical opaque shell; only pixels inside groove_floor change.  Two
downward band passes run in an 8 s loop (4 s each): the first pass is the
approved gold #f4cd63, the second is the approved cyan #5fe1e6.  The colour only
crossfades during the brief off-groove seam, so the visible band never turns a
muddy in-between hue.  No colour is applied by the engine to the stone shell.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageChops

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
CONCEPT_DIR = ROOT / "自制素材" / "提示石碑概念示意"
CONCEPT_SCRIPT = CONCEPT_DIR / "draw_concept.py"
CONCEPT_IMAGE = CONCEPT_DIR / "concept.png"
OUT_DIR = ROOT / "基础场景原型" / "assets" / "tutorial_stele"

STONE_SIZE = (26, 52)
FRAME_COUNT = 64
FPS = 8.0
LOOP_SECONDS = FRAME_COUNT / FPS
BAND_START = -8
BAND_END = 60
SWEEP_SECONDS = LOOP_SECONDS / 2.0
START_FRAME = 8
GOLD = "#f4cd63"
CYAN = "#5fe1e6"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def load_concept_module():
    spec = importlib.util.spec_from_file_location("stele_concept", CONCEPT_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load concept module: {CONCEPT_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def save_png(image: Image.Image, name: str) -> Path:
    path = OUT_DIR / name
    image.save(path, "PNG", optimize=True)
    return path


def row_width(mask: Image.Image, y: int) -> int:
    return sum(1 for x in range(STONE_SIZE[0]) if mask.getpixel((x, y)) > 0)


def diff_pixels(a: Image.Image, b: Image.Image, box: tuple[int, int, int, int] | None = None):
    """Yield (x, y) where two same-size RGBA images differ."""
    width, height = a.size
    x0, y0, x1, y1 = box or (0, 0, width, height)
    pa, pb = a.load(), b.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            if pa[x, y] != pb[x, y]:
                yield x, y


def mask_outside(mask: Image.Image) -> Image.Image:
    out = Image.new("L", STONE_SIZE, 255)
    src = mask.load()
    dst = out.load()
    for y in range(STONE_SIZE[1]):
        for x in range(STONE_SIZE[0]):
            dst[x, y] = 0 if src[x, y] > 0 else 255
    return out


def band_center(frame: Image.Image, grey: Image.Image, mask: Image.Image) -> tuple[int, int]:
    """Return (strongest row, strongest row score) for the lit groove only."""
    best_row = -1
    best_score = 0
    pf, pg, pm = frame.load(), grey.load(), mask.load()
    for y in range(9, 44):
        score = 0
        for x in range(STONE_SIZE[0]):
            if pm[x, y] == 0:
                continue
            fr, fg, fb, _ = pf[x, y]
            gr, gg, gb, _ = pg[x, y]
            score += abs(fr - gr) + abs(fg - gg) + abs(fb - gb)
        if score > best_score:
            best_score = score
            best_row = y
    return best_row, best_score


def colour_mix(t: float) -> float:
    """Hold the approved colours; crossfade only while the band is off-groove.

    Phase 2 of the sweep starts with band_y=-8, so t=0.47..0.53 is entirely
    above the visible groove (and below it just before the wrap).  That is the
    only window where gold/cyan are blended.  The band itself therefore always
    shows one of the two approved colours, never a green midpoint.
    """
    if t <= 0.47:
        return 0.0
    if t >= 0.53:
        return 1.0
    u = (t - 0.47) / (0.53 - 0.47)
    return u * u * (3.0 - 2.0 * u)


def build_animation(concept, grey: Image.Image, gold_ref: Image.Image, cyan_ref: Image.Image, mask: Image.Image):
    frames: list[Image.Image] = []
    centers: list[int | None] = []
    outside = mask_outside(mask)
    for index in range(FRAME_COUNT):
        t = index / FRAME_COUNT
        phase = (t * 2.0) % 1.0
        band_y = int(round(BAND_START + (BAND_END - BAND_START) * phase))
        gold = concept.stone("gold", band_y)
        cyan = concept.stone("cyan", band_y)
        blended = Image.blend(gold, cyan, colour_mix(t))
        frame = grey.copy()
        frame.paste(blended, (0, 0), mask)

        # Hard guarantee: no pixel outside the approved groove can change.
        if any(frame.getpixel((x, y)) != grey.getpixel((x, y))
               for y in range(STONE_SIZE[1])
               for x in range(STONE_SIZE[0])
               if outside.getpixel((x, y)) == 255):
            raise AssertionError(f"frame {index} changed the stone shell")

        center, score = band_center(frame, grey, mask)
        # The soft base tint stays measurable at every frame; a score above 400
        # marks a genuine travelling band rather than the flat groove glow.
        centers.append(center if score > 400 else None)
        frames.append(frame)

    sheet = Image.new("RGBA", (STONE_SIZE[0] * FRAME_COUNT, STONE_SIZE[1]), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        sheet.paste(frame, (index * STONE_SIZE[0], 0))

    # Validate the intended downward travel.  Ignore the frames where the band
    # is outside the groove (the loop seam), then require monotonic descent in
    # each visible run.
    runs: list[list[int]] = []
    current: list[int] = []
    for center in centers:
        if center is None:
            if current:
                runs.append(current)
                current = []
            continue
        current.append(center)
    if current:
        runs.append(current)
    if len(runs) != 2:
        raise AssertionError(f"expected two visible band passes, got {len(runs)}")
    for run in runs:
        if len(run) < 8:
            raise AssertionError(f"band pass too short: {run}")
        if any(b < a for a, b in zip(run, run[1:])):
            raise AssertionError(f"band did not travel downward: {run}")
        if run[0] > 14 or run[-1] < 37:
            raise AssertionError(f"band pass did not cover the groove: {run}")

    # Gold and cyan must both be visible as a groove tint.  At t=0 the colour
    # phase is gold; at t=0.5 it is cyan.  A groove pixel away from the band
    # still carries the 0.27 base light.
    f0 = frames[0].getpixel((12, 26))
    f32 = frames[FRAME_COUNT // 2].getpixel((12, 26))
    if not f0[0] > f0[2]:
        raise AssertionError(f"frame 0 base tint is not gold-dominant: {f0}")
    if not f32[2] > f32[0]:
        raise AssertionError(f"cyan frame base tint is not cyan-dominant: {f32}")

    return frames, sheet, centers, runs


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    concept = load_concept_module()
    if tuple(concept.SIZE) != STONE_SIZE:
        raise AssertionError(f"concept size changed: {concept.SIZE}")

    grey = concept.stone("grey", 26)
    gold = concept.stone("gold", 26)
    cyan = concept.stone("cyan", 26)
    mask = concept.groove_floor()

    # The three reference states and the grey silhouette must be identical.
    if grey.size != STONE_SIZE or gold.size != STONE_SIZE or cyan.size != STONE_SIZE:
        raise AssertionError("reference state size mismatch")
    if len({grey.getchannel("A").tobytes(),
            gold.getchannel("A").tobytes(),
            cyan.getchannel("A").tobytes()}) != 1:
        raise AssertionError("reference states do not share one silhouette")
    for lit in (gold, cyan):
        for x, y in diff_pixels(grey, lit):
            if mask.getpixel((x, y)) == 0:
                raise AssertionError(f"lit reference changed outside mask at {(x, y)}")

    expected_rows = {12: 5, 21: 4, 24: 3, 26: 3, 28: 3, 31: 4, 32: 5, 41: 5}
    for y, width in expected_rows.items():
        actual = row_width(mask, y)
        if actual != width:
            raise AssertionError(f"groove row {y} is {actual}px, expected {width}")

    frames, sheet, centers, runs = build_animation(concept, grey, gold, cyan, mask)
    # At t=0.25 and t=0.75 the band is exactly at band_y=26 and the colour hold
    # makes these two runtime frames pixel-identical to the approved references.
    if ImageChops.difference(frames[16], gold).getbbox() is not None:
        raise AssertionError("frame 16 is not the exact gold band_y=26 reference")
    if ImageChops.difference(frames[48], cyan).getbbox() is not None:
        raise AssertionError("frame 48 is not the exact cyan band_y=26 reference")

    paths = {
        "grey": save_png(grey, "tutorial_stele_grey.png"),
        "gold": save_png(gold, "tutorial_stele_gold.png"),
        "cyan": save_png(cyan, "tutorial_stele_cyan.png"),
        "mask": save_png(
            Image.composite(
                Image.new("RGBA", STONE_SIZE, (255, 255, 255, 255)),
                Image.new("RGBA", STONE_SIZE, (0, 0, 0, 0)),
                mask,
            ),
            "tutorial_stele_groove_mask.png",
        ),
        "sheet": save_png(sheet, "tutorial_stele_frames.png"),
    }

    manifest = {
        "asset": "tutorial_stele",
        "status": "generated from the approved concept script; concept files untouched",
        "source": {
            "concept_script": str(CONCEPT_SCRIPT.relative_to(ROOT)).replace("\\", "/"),
            "concept_script_sha256": sha256(CONCEPT_SCRIPT),
            "concept_sheet": str(CONCEPT_IMAGE.relative_to(ROOT)).replace("\\", "/"),
            "concept_sheet_sha256": sha256(CONCEPT_IMAGE),
            "generator": str(Path(__file__).resolve().relative_to(ROOT)).replace("\\", "/"),
            "generator_sha256": sha256(Path(__file__).resolve()),
        },
        "stone": {
            "size": list(STONE_SIZE),
            "display_scale": 1,
            "filter": "nearest",
            "silhouette": "exact stone() contour, no resize or redraw",
            "grey_state": "exact stone('grey', band_y=26)",
            "gold_reference": "exact stone('gold', band_y=26)",
            "cyan_reference": "exact stone('cyan', band_y=26)",
            "groove_rows": {
                "12": 5, "21": 4, "24": 3, "26": 3, "31": 4, "41": 5,
            },
            "outside_groove": "identical in every reference and animation frame",
        },
        "animation": {
            "frame_count": FRAME_COUNT,
            "frame_size": list(STONE_SIZE),
            "sheet_size": [STONE_SIZE[0] * FRAME_COUNT, STONE_SIZE[1]],
            "fps": FPS,
            "loop_seconds": LOOP_SECONDS,
            "band_sweeps": 2,
            "seconds_per_sweep": SWEEP_SECONDS,
            "band_y_path": [BAND_START, BAND_END],
            "colour_cycle_seconds": LOOP_SECONDS,
            "colour_holds": (
                "first 4 s pass is gold #f4cd63; second 4 s pass is cyan #5fe1e6; "
                "the only crossfade is t=0.47..0.53 while band_y is outside the "
                "groove, so the visible travelling band never shows a blended hue"
            ),
            "reference_frames": {
                "16": "exact gold reference, band_y=26",
                "48": "exact cyan reference, band_y=26",
            },
            "start_frame_in_game": START_FRAME,
            "formula": (
                "frame = stone with band_y=-8+68*((t*2)%1); first half uses the "
                "concept gold image, second half uses the cyan image; a short "
                "smoothstep blend occurs only while band_y is outside 9..43; "
                "pixels outside groove_floor copied from the grey reference"
            ),
            "runtime_only": "tutorial_stele_grey.png and tutorial_stele_frames.png",
        },
        "frames": {
            "path": "基础场景原型/assets/tutorial_stele/tutorial_stele_frames.png",
            "sha256": sha256(paths["sheet"]),
            "size": list(sheet.size),
            "band_centres": centers,
            "visible_runs": runs,
        },
        "files": {},
    }
    for key, path in paths.items():
        with Image.open(path) as image:
            manifest["files"][key] = {
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "sha256": sha256(path),
                "size": list(image.size),
                "mode": image.mode,
            }
    manifest_path = OUT_DIR / "tutorial_stele_manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"Created {len(paths) + 1} files in {OUT_DIR}")
    print(
        "Stone 26x52; references exact at band_y=26; mask rows 5/4/3/4/5; "
        f"{FRAME_COUNT} frames at {FPS:g} FPS, {LOOP_SECONDS:g}s loop."
    )
    print(
        "Validated: identical shell/alpha, light only inside groove, two "
        "downward band passes, gold/cyan held per pass; frames 16/48 match the "
        "approved band_y=26 references exactly."
    )


if __name__ == "__main__":
    main()
