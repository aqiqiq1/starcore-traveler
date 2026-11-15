"""Low-cost protection check for the level-flow/pause task.

Compares the 146-file baseline captured before implementation.  Only the five
explicitly allowed existing scripts may differ; both production scene files,
project.godot, player/star-core/rune/stele/exit scripts and all art assets must
keep their SHA-256.  New test/doc files were not in the baseline and are listed
separately.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

BASELINE = Path(
    r"C:\Users\aqiqiqi\AppData\Local\Temp\opencode"
    r"\level-flow-pause-ba5b99b3f2af4abd8a7c5e006b58cb59\before.json"
)
PROJECT = Path(r"D:\godot game\星核旅人\基础场景原型")
LOG = PROJECT / "tests" / "logs" / "level_flow_pause_protection.json"

ALLOWED_CHANGED = {
    "scripts/level_01.gd",
    "scripts/level_02.gd",
    "scripts/level_hud.gd",
    "scripts/level_02_hud.gd",
    "scripts/start_menu.gd",
}

PROTECTED_HIGHLIGHTS = [
    "project.godot",
    "scenes/level_01.tscn",
    "scenes/level_02.tscn",
    "scripts/player.gd",
    "scenes/player.tscn",
    "scripts/star_core_interaction_room.gd",
    "scripts/rune_stone_field.gd",
    "scripts/tutorial_stele.gd",
    "scripts/level_exit.gd",
    "scripts/main.gd",
    "scenes/main.tscn",
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def main() -> int:
    baseline = json.loads(BASELINE.read_text(encoding="utf-8-sig"))
    changed: list[str] = []
    missing: list[str] = []
    unchanged = 0
    for entry in baseline:
        path = Path(entry["path"])
        if not path.exists():
            missing.append(str(path))
            continue
        current = sha256(path)
        try:
            relative = path.resolve().relative_to(PROJECT.resolve()).as_posix()
        except ValueError:
            relative = str(path)
        if current != entry["sha256"].upper():
            changed.append(relative)
        else:
            unchanged += 1

    unauthorized = sorted(set(changed) - ALLOWED_CHANGED)
    highlight = {}
    by_rel = {
        Path(entry["path"]).resolve().relative_to(PROJECT.resolve()).as_posix(): entry
        for entry in baseline
        if Path(entry["path"]).resolve().is_relative_to(PROJECT.resolve())
    }
    for relative in PROTECTED_HIGHLIGHTS:
        entry = by_rel.get(relative)
        if entry is None:
            highlight[relative] = "not-in-baseline"
            continue
        path = Path(entry["path"])
        highlight[relative] = (
            "unchanged" if path.exists() and sha256(path) == entry["sha256"].upper() else "CHANGED"
        )

    report = {
        "baseline_files": len(baseline),
        "unchanged": unchanged,
        "changed": changed,
        "missing": missing,
        "allowed_changed": sorted(ALLOWED_CHANGED),
        "unauthorized_changed": unauthorized,
        "protected_highlights": highlight,
        "result": "PASS" if not unauthorized and not missing else "FAIL",
    }
    LOG.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
