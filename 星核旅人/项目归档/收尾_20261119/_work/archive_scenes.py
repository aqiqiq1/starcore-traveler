"""Reversible move of non-runtime scenes (with their dedicated scripts/sidecars)
out of the Godot project into 非运行资料/历史测试与证据/, preserving the
project-relative path. Same-volume rename, SHA-256 verified, no overwrite.

Dry-run by default; pass --apply to execute.
"""
from __future__ import annotations

import csv
import hashlib
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(r"D:\godot game\星核旅人\基础场景原型")
ARCH = Path(r"D:\godot game\星核旅人\非运行资料\历史测试与证据")
OUTDIR = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")

SAND_SCENES = [
    "scenes/main.tscn",
    "scenes/polarity_record_test_room.tscn",
    "scenes/polarity_record_test_room_standalone.tscn",
    "scenes/star_core_bay_interactable.tscn",
    "scenes/star_core_interaction_room.tscn",
    "scenes/star_core_interaction_standalone.tscn",
    "scenes/tutorial_stele.tscn",
    "scenes/tutorial_stele_demo.tscn",
    "scenes/enemies/polarity_golem_guard.tscn",
    "scenes/experiments/polarity_golem_experiment.tscn",
]
SAND_SCRIPTS = [
    "scripts/main.gd",
    "scripts/anchor_room.gd",
    "scripts/background.gd",
    "scripts/polarity_record_test_room.gd",
    "scripts/polarity_record_test_standalone.gd",
    "scripts/star_core_interaction_standalone.gd",
    "scripts/tutorial_stele.gd",
    "scripts/experiments/polarity_golem_enemy.gd",
    "scripts/experiments/polarity_golem_experiment.gd",
    "scripts/experiments/polarity_golem_hud.gd",
]
TOOL_FILES = [
    "tools/bridge_ground_capture.tscn",
    "tools/bridge_ground_capture.gd",
    "tools/bridge_ground_capture.gd.uid",
    "tools/capture_anchor.tscn",
    "tools/capture_anchor.gd",
    "tools/capture_anchor.gd.uid",
    "tools/capture_polarity_record.tscn",
    "tools/capture_polarity_record.gd",
    "tools/capture_polarity_record.gd.uid",
    "tools/capture_screenshots.tscn",
    "tools/capture_screenshots.gd",
    "tools/capture_screenshots.gd.uid",
    "tools/capture_screenshots.ps1",
    "tools/capture_star_core_interaction.tscn",
    "tools/capture_star_core_interaction.gd",
    "tools/capture_star_core_interaction.gd.uid",
    "tools/compact_header_capture.tscn",
    "tools/compact_header_capture.gd",
    "tools/compact_header_capture.gd.uid",
    "tools/preview_polarity_link.tscn",
    "tools/preview_polarity_link.gd",
    "tools/preview_polarity_link.gd.uid",
    "tools/preview_rune_stone.tscn",
    "tools/preview_rune_stone.gd",
    "tools/preview_rune_stone.gd.uid",
    "tools/preview_rune_stone_art_revision.tscn",
    "tools/preview_rune_stone_art_revision.gd",
    "tools/preview_rune_stone_art_revision.gd.uid",
    "tools/preview_star_core.tscn",
    "tools/preview_star_core.gd",
    "tools/preview_star_core.gd.uid",
    "tools/preview_star_core_animation.tscn",
    "tools/preview_star_core_animation.gd",
    "tools/preview_star_core_animation.gd.uid",
    "tools/preview_star_core_bay.tscn",
    "tools/preview_star_core_bay.gd",
    "tools/preview_star_core_bay.gd.uid",
    "tools/preview_star_core_lid.tscn",
    "tools/preview_star_core_lid.gd",
    "tools/preview_star_core_lid.gd.uid",
]

DIR_GROUPS = [
    ("test_harness", "tests"),
    ("preview_capture", "previews/layered_core_brightness_v2_20261118"),
]


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with p.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def collect() -> list[tuple[str, str]]:
    """(project-relative source, group)."""
    out: list[tuple[str, str]] = []
    for s in SAND_SCENES:
        out.append((s, "sandbox_scene"))
    for s in SAND_SCRIPTS:
        out.append((s, "sandbox_script"))
        if (ROOT / (s + ".uid")).exists():
            out.append((s + ".uid", "sandbox_script"))
    for s in TOOL_FILES:
        out.append((s, "capture_tool"))
    for group, d in DIR_GROUPS:
        base = ROOT / d
        for p in sorted(base.rglob("*")):
            if p.is_file():
                out.append((p.relative_to(ROOT).as_posix(), group))
    return out


def main() -> None:
    apply = "--apply" in sys.argv
    items = collect()

    missing = [s for s, _ in items if not (ROOT / s).exists()]
    if missing:
        print("MISSING SOURCES:")
        for m in missing:
            print("  ", m)
        raise SystemExit(1)

    clashes = [s for s, _ in items if (ARCH / s).exists()]
    if clashes:
        print("TARGET ALREADY EXISTS (abort):")
        for c in clashes:
            print("  ", c)
        raise SystemExit(1)

    total_bytes = sum((ROOT / s).stat().st_size for s, _ in items)
    print(f"files={len(items)} bytes={total_bytes}")
    if not apply:
        for s, g in items[:20]:
            print("  DRY", g, s)
        print("  ...")
        return

    rows = []
    for rel, group in items:
        src = ROOT / rel
        dst = ARCH / rel
        before = sha256(src)
        size = src.stat().st_size
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src), str(dst))
        after = sha256(dst)
        if src.exists() or not dst.exists() or before != after:
            raise SystemExit(f"VERIFY FAILED: {rel}")
        rows.append(
            {
                "group": group,
                "old_project_path": "res://" + rel,
                "archive_path": str(dst),
                "bytes": size,
                "sha256": before,
                "restore_to": "res://" + rel,
            }
        )

    csv_path = OUTDIR / "archive_manifest_20261119.csv"
    with csv_path.open("w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(
            fh,
            fieldnames=["group", "old_project_path", "archive_path", "bytes", "sha256", "restore_to"],
        )
        w.writeheader()
        w.writerows(rows)

    # remove empty source directories under scenes/, scripts/, tools/, tests/
    for d in sorted({(ROOT / Path(s).parent).as_posix() for s, _ in items}, reverse=True):
        p = Path(d)
        for cand in [p, *p.parents]:
            if str(cand) == str(ROOT) or not cand.exists():
                continue
            if cand.is_dir() and not any(cand.iterdir()) and cand != ROOT / "scenes":
                cand.rmdir()

    print(f"moved={len(rows)} manifest={csv_path}")


if __name__ == "__main__":
    main()
