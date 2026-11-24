"""Rename the non-compliant runtime asset filenames, keeping .import UIDs.

Writes asset_rename_map.csv with old/new paths, pre/post UID, hash and every
non-Markdown file whose text was rewritten. Dry-run unless --apply.
"""
from __future__ import annotations

import csv
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
OUTDIR = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")

RENAMES: list[tuple[str, str]] = [
    # character sheets: hyphen -> snake_case
    ("assets/characters/male_hero-idle.png", "assets/characters/male_hero_idle.png"),
    ("assets/characters/male_hero-walk.png", "assets/characters/male_hero_walk.png"),
    ("assets/characters/male_hero-run.png", "assets/characters/male_hero_run.png"),
    ("assets/characters/male_hero-jump.png", "assets/characters/male_hero_jump.png"),
    ("assets/characters/male_hero-fall.png", "assets/characters/male_hero_fall.png"),
    ("assets/characters/male_hero-fall_loop.png", "assets/characters/male_hero_fall_loop.png"),
    # shared attack frames (runtime hero combo sheet)
    (
        "assets/experiments/polarity_golem/hero/male_hero-combo_1.png",
        "assets/experiments/polarity_golem/hero/male_hero_combo_1.png",
    ),
    (
        "assets/experiments/polarity_golem/hero/male_hero-combo_1_end.png",
        "assets/experiments/polarity_golem/hero/male_hero_combo_1_end.png",
    ),
    # exit portal sheet: drop the v2 trial suffix
    (
        "assets/checkpoint_exit/gate_portal_fx_v2_8f.png",
        "assets/checkpoint_exit/gate_portal_fx_8f.png",
    ),
    # SFX: drop v2/v5 trial suffixes
    ("assets/audio_demo_v2_20261116/polarity_switch_v2.wav", "assets/audio_demo_v2_20261116/polarity_switch.wav"),
    ("assets/audio_demo_v2_20261116/swing_v2.wav", "assets/audio_demo_v2_20261116/swing.wav"),
    (
        "assets/audio_demo_v2_20261116/shell_shatter_heavy_v2.wav",
        "assets/audio_demo_v2_20261116/shell_shatter_heavy.wav",
    ),
    ("assets/level03_prototype/audio_charge_v2.ogg", "assets/level03_prototype/audio_charge.ogg"),
    ("assets/level03_prototype/audio_slam_v5.ogg", "assets/level03_prototype/audio_slam.ogg"),
    # approved second-platform linked crystal (was still named "candidate")
    (
        "assets/interaction_projection_20261117/layered_core/layered_linked_candidate_base_200x60.png",
        "assets/interaction_projection_20261117/layered_core/layered_linked_crystal_base_200x60.png",
    ),
    (
        "assets/interaction_projection_20261117/layered_core/layered_linked_candidate_active_200x60.png",
        "assets/interaction_projection_20261117/layered_core/layered_linked_crystal_active_200x60.png",
    ),
    (
        "assets/interaction_projection_20261117/layered_core/layered_linked_candidate_mask_200x60.png",
        "assets/interaction_projection_20261117/layered_core/layered_linked_crystal_mask_200x60.png",
    ),
    (
        "assets/interaction_projection_20261117/layered_core/layered_linked_candidate_arrival_200x60.png",
        "assets/interaction_projection_20261117/layered_core/layered_linked_crystal_arrival_200x60.png",
    ),
    (
        "assets/interaction_projection_20261117/layered_core/layered_linked_candidate_facetid_200x60.png",
        "assets/interaction_projection_20261117/layered_core/layered_linked_crystal_facetid_200x60.png",
    ),
]

# Non-Markdown text files whose references must follow the rename.
TEXT_SUFFIXES = {".gd", ".tscn", ".scn", ".json", ".py", ".ps1", ".cfg", ".html", ".tres"}
SKIP_PARTS = {".godot", "项目归档"}
SKIP_PREFIXES = ("tests/logs/",)


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def import_uid(p: Path) -> str:
    side = p.with_name(p.name + ".import")
    if not side.exists():
        return ""
    m = re.search(r'uid="(uid://[^"]+)"', side.read_text(encoding="utf-8", errors="replace"))
    return m.group(1) if m else ""


def main() -> None:
    apply = "--apply" in sys.argv
    missing = [o for o, n in RENAMES if not (ROOT / o).exists()]
    if missing:
        print("MISSING:", missing)
        raise SystemExit(1)
    clashes = [n for o, n in RENAMES if (ROOT / n).exists()]
    if clashes:
        print("TARGET EXISTS:", clashes)
        raise SystemExit(1)

    rows = []
    for old, new in RENAMES:
        src = ROOT / old
        dst = ROOT / new
        rows.append(
            {
                "old_path": "res://" + old,
                "new_path": "res://" + new,
                "bytes": src.stat().st_size,
                "sha256": sha256(src),
                "import_uid_before": import_uid(src),
                "import_uid_after": "",
                "rewritten_references": "",
            }
        )

    if not apply:
        for r in rows:
            print("DRY", r["old_path"], "->", r["new_path"], r["import_uid_before"])
        return

    # 1) move payload + sidecar, patch source_file inside the .import
    for (old, new), row in zip(RENAMES, rows):
        src, dst = ROOT / old, ROOT / new
        src.rename(dst)
        side_old = ROOT / (old + ".import")
        if side_old.exists():
            side_new = ROOT / (new + ".import")
            text = side_old.read_bytes().decode("utf-8")
            text = text.replace('source_file="res://' + old + '"', 'source_file="res://' + new + '"')
            side_old.unlink()
            side_new.write_bytes(text.encode("utf-8"))
        row["import_uid_after"] = import_uid(dst)

    # 2) rewrite references in non-Markdown text files
    #    a) full project paths everywhere
    #    b) basenames only for names that have no same-named original outside
    #       assets/ (audio, gate fx, linked crystal); character sheets are kept
    #       safer because individual_sheets/ holds same-named originals.
    old_new_pairs = [(o, n) for o, n in RENAMES]
    basename_pairs = [
        (Path(o).name, Path(n).name)
        for o, n in RENAMES
        if not Path(o).name.startswith("male_hero")
    ]
    touched: dict[str, list[str]] = {}
    for p in sorted(ROOT.rglob("*")):
        if not p.is_file() or p.suffix.lower() not in TEXT_SUFFIXES:
            continue
        rel = p.relative_to(ROOT).as_posix()
        if set(p.relative_to(ROOT).parts) & SKIP_PARTS:
            continue
        if rel.startswith(SKIP_PREFIXES):
            continue
        try:
            raw = p.read_bytes()
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            continue
        new_text = text
        hits = []
        for old, new in old_new_pairs:
            if old in new_text:
                hits.append(old)
                new_text = new_text.replace(old, new)
        for old_name, new_name in basename_pairs:
            if old_name in new_text:
                hits.append(old_name)
                new_text = new_text.replace(old_name, new_name)
        if new_text != text:
            p.write_bytes(new_text.encode("utf-8"))
            touched[rel] = hits

    for row in rows:
        old = row["old_path"][len("res://"):]
        row["rewritten_references"] = " | ".join(
            sorted(k for k, v in touched.items() if old in v)
        )

    csv_path = OUTDIR / "asset_rename_map.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    print("renamed", len(rows))
    print("files with rewritten references", len(touched))
    for k, v in sorted(touched.items()):
        print("  ", k, "->", len(v), "replacements")
    print("map", csv_path)


if __name__ == "__main__":
    main()
