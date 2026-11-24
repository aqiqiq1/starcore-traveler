#!/usr/bin/env python3
"""Generate the in-game rune-stone states from the approved concept sprite().

The approved look is not re-drawn here. This script imports
``../符石概念示意/generate_concept.py`` and calls its ``sprite('sleep'/'gold'/'cyan')``
function to obtain the original 96x96 images, then converts each one to 32x32
with a direct NEAREST resample. The concept canvas (concept.png) is never
cropped, scaled as a whole, or retouched.

Outputs in this directory:

    source_96/rune_stone_sleep_96.png      original concept sprite, 96x96
    source_96/rune_stone_gold_96.png       original concept sprite, 96x96
    source_96/rune_stone_cyan_96.png       original concept sprite, 96x96
    rune_stone_sleep.png                   direct NEAREST 32x32, dormant
    rune_stone_gold.png                    direct NEAREST 32x32, gold
    rune_stone_cyan.png                    direct NEAREST 32x32, cyan
    preview_concept96_vs_direct32.png      side-by-side fidelity comparison
    preview_rune_stone_states.png          updated three-state contact sheet
    manifest.json                          hashes and verification data

Run with the project-pinned environment:

    D:\\minic\\envs\\2024212971\\python.exe generate_rune_stone_assets.py

Only Pillow and the approved concept script are read; this script writes only
its own directory. No third-party image is used.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(__file__).resolve().parent
CONCEPT_DIR = OUT_DIR.parent / "符石概念示意"
CONCEPT_SCRIPT = CONCEPT_DIR / "generate_concept.py"
CONCEPT_PAGE = CONCEPT_DIR / "concept.png"
SOURCE_DIR = OUT_DIR / "source_96"

STATES = ("sleep", "gold", "cyan")
STATE_LABELS = {
    "sleep": ("休眠 / 无光暗芯", "#b9c8ca"),
    "gold": ("链接 · 金 / #F4CD63", "#f4cd63"),
    "cyan": ("链接 · 青 / #5FE1E6", "#5fe1e6"),
}
POSITIVE = (244, 205, 99)
NEGATIVE = (95, 225, 230)
SIZE_96 = 96
SIZE_32 = 32
NEAREST_RATIO = SIZE_96 // SIZE_32


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_concept_module():
    """Import the approved concept script without modifying its directory."""
    if not CONCEPT_SCRIPT.is_file():
        raise FileNotFoundError(f"approved concept script missing: {CONCEPT_SCRIPT}")
    spec = importlib.util.spec_from_file_location(
        "approved_rune_concept", CONCEPT_SCRIPT
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {CONCEPT_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def direct_nearest_32(source: Image.Image) -> Image.Image:
    """Return the direct 3:1 NEAREST conversion of a 96x96 concept sprite.

    Pillow's NEAREST uses destination-centre sampling. The independent sampler
    below repeats that rule so the conversion cannot silently drift to a
    different filter or crop. No pixel is blended, moved or hand-edited.
    """
    if source.size != (SIZE_96, SIZE_96):
        raise ValueError(f"concept sprite must be 96x96, got {source.size}")
    converted = source.resize((SIZE_32, SIZE_32), Image.Resampling.NEAREST)

    # Independent direct NEAREST sampling: destination pixel (x, y) reads the
    # source pixel at floor((x + 0.5) * 3), floor((y + 0.5) * 3).
    expected = Image.new("RGBA", (SIZE_32, SIZE_32), (0, 0, 0, 0))
    src = source.convert("RGBA")
    dst = expected.load()
    src_px = src.load()
    for y in range(SIZE_32):
        sy = min(SIZE_96 - 1, int(math.floor((y + 0.5) * NEAREST_RATIO)))
        for x in range(SIZE_32):
            sx = min(SIZE_96 - 1, int(math.floor((x + 0.5) * NEAREST_RATIO)))
            dst[x, y] = src_px[sx, sy]
    if converted.tobytes() != expected.tobytes():
        raise AssertionError("Pillow NEAREST output differs from the direct sampler")
    return converted


def is_near(pixel: tuple[int, int, int, int], target: tuple[int, int, int], radius: int) -> bool:
    return (
        pixel[3] == 255
        and (pixel[0] - target[0]) ** 2
        + (pixel[1] - target[1]) ** 2
        + (pixel[2] - target[2]) ** 2
        <= radius * radius
    )


def count_near(image: Image.Image, target: tuple[int, int, int], radius: int) -> int:
    return sum(1 for pixel in image.getdata() if is_near(pixel, target, radius))


def verify_state_set(sources: dict[str, Image.Image], displays: dict[str, Image.Image]) -> dict:
    if set(sources) != set(STATES) or set(displays) != set(STATES):
        raise AssertionError("missing one of the three concept states")

    for state in STATES:
        if sources[state].size != (SIZE_96, SIZE_96):
            raise AssertionError(f"{state} source is not 96x96")
        if displays[state].size != (SIZE_32, SIZE_32):
            raise AssertionError(f"{state} display is not 32x32")
        if displays[state].convert("RGBA").tobytes() != direct_nearest_32(
            sources[state]
        ).tobytes():
            raise AssertionError(f"{state} display is not direct NEAREST 32x32")

    # The three states must share the exact same approved silhouette.
    alpha0 = sources["sleep"].getchannel("A").tobytes()
    for state in STATES[1:]:
        if sources[state].getchannel("A").tobytes() != alpha0:
            raise AssertionError(f"{state} source silhouette differs from sleep")
        if displays[state].getchannel("A").tobytes() != displays["sleep"].getchannel("A").tobytes():
            raise AssertionError(f"{state} display silhouette differs from sleep")

    opaque_96 = sum(1 for p in sources["sleep"].getdata() if p[3] == 255)
    opaque_32 = sum(1 for p in displays["sleep"].getdata() if p[3] == 255)
    if opaque_96 != 4807:
        raise AssertionError(f"approved concept shell changed: {opaque_96} opaque px at 96")
    if opaque_32 != 535:
        raise AssertionError(f"direct 32 conversion silhouette changed: {opaque_32} opaque px")

    # The concept's core palette is shaded inward (f = .43 / .70 / .90 / 1.0
    # plus a light pool), so accept the whole authored family, not one hex.
    # Dormant still has zero pixels within the same radius of either accent.
    accent_radius = 55
    sleep_gold = count_near(displays["sleep"], POSITIVE, accent_radius)
    sleep_cyan = count_near(displays["sleep"], NEGATIVE, accent_radius)
    if sleep_gold != 0 or sleep_cyan != 0:
        raise AssertionError("dormant state contains gold/cyan light")

    gold_core = count_near(displays["gold"], POSITIVE, accent_radius)
    cyan_core = count_near(displays["cyan"], NEGATIVE, accent_radius)
    if gold_core < 20 or cyan_core < 20:
        raise AssertionError("lit state lost its coloured core")

    diff_gold_sleep = sum(
        1
        for a, b in zip(displays["gold"].getdata(), displays["sleep"].getdata())
        if a != b
    )
    diff_cyan_sleep = sum(
        1
        for a, b in zip(displays["cyan"].getdata(), displays["sleep"].getdata())
        if a != b
    )
    diff_gold_cyan = sum(
        1
        for a, b in zip(displays["gold"].getdata(), displays["cyan"].getdata())
        if a != b
    )
    if min(diff_gold_sleep, diff_cyan_sleep, diff_gold_cyan) < 100:
        raise AssertionError("one state pair is not visually distinct")

    return {
        "source_96_size": [SIZE_96, SIZE_96],
        "display_32_size": [SIZE_32, SIZE_32],
        "conversion": "direct NEAREST, exact 3:1, destination-centre sampling",
        "opaque_source_96": opaque_96,
        "opaque_display_32": opaque_32,
        "same_silhouette_all_states": True,
        "sleep_near_gold_pixels": sleep_gold,
        "sleep_near_cyan_pixels": sleep_cyan,
        "gold_near_accent_pixels": gold_core,
        "cyan_near_accent_pixels": cyan_core,
        "changed_pixels_gold_vs_sleep": diff_gold_sleep,
        "changed_pixels_cyan_vs_sleep": diff_cyan_sleep,
        "changed_pixels_gold_vs_cyan": diff_gold_cyan,
    }


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = "C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"
    return ImageFont.truetype(path, size)


def save_comparison(sources: dict[str, Image.Image], displays: dict[str, Image.Image]) -> None:
    """Approved 96px sprite x6 next to direct 32px NEAREST x18, three states."""
    cell = 96 * 6
    pad = 24
    label_h = 50
    header_h = 70
    width = pad + (cell + pad) * 2
    height = header_h + (cell + label_h + pad) * len(STATES) + pad
    page = Image.new("RGB", (width, height), "#141d24")
    draw = ImageDraw.Draw(page)
    draw.text(
        (pad, 12),
        "批准 96px 概念 sprite（整数 6x） vs 直接 NEAREST 到 32px（整数 18x）",
        font=font(24, True),
        fill="#e5e8e2",
    )
    draw.text(
        (pad, 42),
        "concept.sprite('sleep'/'gold'/'cyan') 96x96 -> direct NEAREST 32x32; exact 3:1; no crop / no retouch",
        font=font(14),
        fill="#a9bbc1",
    )
    for row, state in enumerate(STATES):
        top = header_h + row * (cell + label_h + pad)
        for col, (image, heading) in enumerate(
            [(sources[state], "96px source x6"), (displays[state], "32px NEAREST x18")]
        ):
            x = pad + col * (cell + pad)
            enlarged = image.convert("RGBA").resize(
                (cell, cell), Image.Resampling.NEAREST
            )
            draw.rectangle(
                (x - 4, top - 4, x + cell + 3, top + cell + 3), fill="#1d2932"
            )
            page.paste(enlarged, (x, top), enlarged)
            draw.text(
                (x, top + cell + 8),
                f"{STATE_LABELS[state][0]}  /  {heading}",
                font=font(18, True),
                fill=STATE_LABELS[state][1],
            )
    page.save(OUT_DIR / "preview_concept96_vs_direct32.png")


def save_state_sheet(displays: dict[str, Image.Image]) -> None:
    """Updated three-state 640x360 sheet, 5x integer + actual 1x."""
    sheet = Image.new("RGB", (640, 360), "#0a1216")
    draw = ImageDraw.Draw(sheet)
    draw.rectangle((0, 0, 639, 44), fill="#0e191e")
    draw.line((0, 44, 640, 44), fill="#375258", width=1)
    draw.text(
        (18, 8),
        "RUNE STONE - CONCEPT SPRITE DIRECT 96->32 NEAREST",
        font=font(17, True),
        fill="#dce8e4",
    )
    draw.text(
        (18, 27),
        "sleep / gold / cyan; same approved shell and crack network; three pre-composed state PNGs",
        font=font(10),
        fill="#8fa8a9",
    )

    scale = 5
    cell = SIZE_32 * scale
    centers = [88, 320, 552]
    for index, state in enumerate(STATES):
        cx = centers[index]
        left = cx - cell // 2
        top = 66
        for yy in range(0, cell, 10):
            for xx in range(0, cell, 10):
                shade = (18, 28, 32) if ((xx // 10) + (yy // 10)) % 2 == 0 else (22, 33, 37)
                draw.rectangle((left + xx, top + yy, left + xx + 9, top + yy + 9), fill=shade)
        draw.rectangle((left, top, left + cell, top + cell), outline=(43, 65, 70))
        enlarged = displays[state].convert("RGBA").resize(
            (cell, cell), Image.Resampling.NEAREST
        )
        sheet.paste(enlarged, (left, top), enlarged)
        draw.text(
            (cx - 62, top + cell + 8),
            STATE_LABELS[state][0],
            font=font(14, True),
            fill=STATE_LABELS[state][1],
        )
        draw.text(
            (cx - 62, top + cell + 27),
            "32x32 / 5x here / direct 96->32",
            font=font(9),
            fill="#7d9698",
        )
        native = displays[state].convert("RGBA")
        sheet.paste(native, (cx - SIZE_32 // 2, top + cell + 44), native)

    draw.line((0, 326, 640, 326), fill="#2a4247", width=1)
    draw.rectangle((0, 327, 639, 359), fill="#0c161a")
    draw.text(
        (18, 333),
        "SOURCE OF TRUTH: 自制素材/符石概念示意/generate_concept.py sprite(); NO REDRAWN OUTLINE OR CRACKS.",
        font=font(9),
        fill="#bcc9c1",
    )
    draw.text(
        (18, 346),
        "IN-GAME DISPLAY: 32x32 NEAREST; gold/cyan preserve the concept's coloured core, inner wall and reflection.",
        font=font(9),
        fill="#809796",
    )
    sheet.save(OUT_DIR / "preview_rune_stone_states.png")


def main() -> None:
    concept = load_concept_module()
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)

    sources: dict[str, Image.Image] = {}
    displays: dict[str, Image.Image] = {}
    for state in STATES:
        sprite = concept.sprite(state)
        if sprite.size != (SIZE_96, SIZE_96):
            raise AssertionError(f"concept.sprite({state!r}) is {sprite.size}, expected 96x96")
        sprite = sprite.convert("RGBA")
        # A second call must be byte-identical: the approved sprite is deterministic.
        if sprite.tobytes() != concept.sprite(state).convert("RGBA").tobytes():
            raise AssertionError(f"concept.sprite({state!r}) is not deterministic")
        sources[state] = sprite
        displays[state] = direct_nearest_32(sprite)
        sprite.save(SOURCE_DIR / f"rune_stone_{state}_96.png")
        displays[state].save(OUT_DIR / f"rune_stone_{state}.png")

    stats = verify_state_set(sources, displays)
    save_comparison(sources, displays)
    save_state_sheet(displays)

    manifest = {
        "name": "裂隙符石 / Rune Stone",
        "version": "concept-derived direct 96->32 NEAREST (2026-10-31)",
        "review_status": "generated only from the approved concept sprite(); awaiting user review; not re-designed",
        "art_source": {
            "concept_page": "../符石概念示意/concept.png",
            "sprite_function": "../符石概念示意/generate_concept.py: sprite('sleep'/'gold'/'cyan')",
            "note": "the 1600x1000 concept page is never cropped or used as a texture; only the original 96x96 sprite() images are converted",
        },
        "conversion": {
            "source": "96x96 RGBA concept sprite",
            "target": "32x32 RGBA display texture",
            "method": "direct NEAREST, exact 3:1, destination-centre sampling via Pillow Image.Resampling.NEAREST",
            "no_blending": True,
            "no_manual_retouch": True,
        },
        "component_scene": "res://scenes/rune_stone_visual.tscn",
        "component_script": "res://scripts/rune_stone_visual.gd",
        "preview_scene": "res://tools/preview_rune_stone_art_revision.tscn",
        "preview_capture": "res://screenshots/rune_stone_art_revision.png",
        "gameplay_connection": "none; force, collision, map, proximity and F2/F7 state remain owned by the existing components",
        "integrations": {
            "f7_record_room": "existing RuneStoneField/visual; initial inactive, first light-up and polarity commit timing unchanged",
            "f2_anchor_room": "existing shared visual at (320,200), fixed GOLD; no force, collision or route change",
        },
        "logical_size": [SIZE_32, SIZE_32],
        "origin": "image centre; centred Sprite2D at 1:1; integer 4x review scaling only",
        "display_architecture": {
            "base": "sleep state PNG, always visible, provides the exact approved dormant shell/core",
            "accent": "gold or cyan whole-state PNG overlay; alpha 1 when settled, 0 when dormant",
            "transition": "old accent alpha 1->0 during the dim fraction, then target accent 0->1; completion and transition_finished timing unchanged",
            "why": "keeps the concept's baked coloured core, inner-wall reflection and highlights instead of collapsing them into an approximated shell + white mask",
        },
        "states": [
            {
                "state": state,
                "source_96": f"source_96/rune_stone_{state}_96.png",
                "display_32": f"rune_stone_{state}.png",
                "sha256_source_96": sha256(SOURCE_DIR / f"rune_stone_{state}_96.png"),
                "sha256_display_32": sha256(OUT_DIR / f"rune_stone_{state}.png"),
            }
            for state in STATES
        ],
        "polarity_colors": {"positive": "#f4cd63", "negative": "#5fe1e6"},
        "same_silhouette_all_states": True,
        "inactive": "sleep state PNG: same approved shell and crack network, dark core, no gold or cyan light",
        "rotation": "none",
        "float_animation": "none",
        "hint_symbol": "drawn outside the 32x32 stone by the Godot component; not baked",
        "preview_comparison": "preview_concept96_vs_direct32.png",
        "preview_states": "preview_rune_stone_states.png",
        "third_party_images": "none",
        "generator": Path(__file__).name,
        "stats": stats,
        "sha256": {
            "preview_concept96_vs_direct32.png": sha256(OUT_DIR / "preview_concept96_vs_direct32.png"),
            "preview_rune_stone_states.png": sha256(OUT_DIR / "preview_rune_stone_states.png"),
        },
    }
    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    for state in STATES:
        print(
            f"WROTE {state}: source_96 sha256={sha256(SOURCE_DIR / f'rune_stone_{state}_96.png')} "
            f"display_32 sha256={sha256(OUT_DIR / f'rune_stone_{state}.png')}"
        )
    print(f"VERIFY {stats}")
    print(f"WROTE preview_concept96_vs_direct32.png {Image.open(OUT_DIR / 'preview_concept96_vs_direct32.png').size}")
    print(f"WROTE preview_rune_stone_states.png {Image.open(OUT_DIR / 'preview_rune_stone_states.png').size}")


if __name__ == "__main__":
    main()
