#!/usr/bin/env python3
"""Verify the Godot global script class cache and the archived backups.

Read-only. Expected paths are the five classes that previously resolved into the
backup tree; the cache must have no '项目归档' entry and no duplicate class.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / ".godot" / "global_script_class_cache.cfg"
BACKUP = ROOT / "项目归档" / "关卡改版前_20261113" / "L2_unified_ground"
REPORT = ROOT / "tests" / "logs" / "class_cache_verify_20261114.json"

EXPECTED = {
    "RuneStoneField": "res://scripts/rune_stone_field.gd",
    "BayRuneLink": "res://scripts/bay_rune_link.gd",
    "Level02": "res://scripts/level_02.gd",
    "Level02HUD": "res://scripts/level_02_hud.gd",
    "TutorialStele": "res://scripts/tutorial_stele.gd",
    "CompactLevelHeader": "res://scripts/ui/compact_level_header.gd",
}

UID_NAMES = [
    "bay_rune_link.gd",
    "level_02.gd",
    "level_02_hud.gd",
    "rune_stone_field.gd",
    "tutorial_stele.gd",
]

PAIRS = re.compile(r'"class": &"([^"]+)"[\s\S]*?"path": "([^"]+)"')


def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    text = CACHE.read_text(encoding="utf-8", errors="replace")
    pairs = PAIRS.findall(text)
    by_class: dict[str, list[str]] = {}
    for name, path in pairs:
        by_class.setdefault(name, []).append(path)
    failures: list[str] = []
    archive_refs = text.count("项目归档")
    if archive_refs:
        failures.append(f"cache contains {archive_refs} archive reference(s)")
    for name, path in sorted(by_class.items()):
        if len(path) > 1:
            failures.append(f"duplicate class {name}: {path}")
    for name, expected in EXPECTED.items():
        actual = by_class.get(name, [])
        if actual != [expected]:
            failures.append(f"{name}: expected [{expected}], got {actual}")

    backup_rows: list[dict] = []
    manifest = json.loads((BACKUP / "MANIFEST.json").read_text(encoding="utf-8"))
    for row in manifest["files"]:
        src = BACKUP / row["path"]
        ok = src.exists() and sha(src) == row["sha256"]
        backup_rows.append({"path": row["path"], "sha256": row["sha256"], "ok": ok})
        if not ok:
            failures.append(f"backup hash mismatch: {row['path']}")
    addendum = json.loads(
        (BACKUP / "MANIFEST_addendum_tutorial_stele.json").read_text(encoding="utf-8")
    )
    src = BACKUP / addendum["path"]
    ok = src.exists() and sha(src) == addendum["sha256"]
    backup_rows.append({"path": addendum["path"], "sha256": addendum["sha256"], "ok": ok})
    if not ok:
        failures.append(f"backup hash mismatch: {addendum['path']}")
    if not (ROOT / "项目归档" / ".gdignore").exists():
        failures.append("项目归档/.gdignore is missing")
    if len(backup_rows) != 10:
        failures.append(f"expected 10 backup content files, got {len(backup_rows)}")

    uid_rows: list[dict] = []
    seen_uids: dict[str, str] = {}
    for name in UID_NAMES:
        formal = ROOT / "scripts" / (name + ".uid")
        archived = BACKUP / "scripts" / (name + ".uid")
        for label, path in (("formal", formal), ("backup", archived)):
            if not path.exists():
                failures.append(f"missing {label} UID for {name}")
                continue
            value = path.read_text(encoding="utf-8", errors="replace").strip()
            uid_rows.append({"name": name, "scope": label, "uid": value})
            if value in seen_uids:
                failures.append(f"duplicate UID {value}: {seen_uids[value]} and {label} {name}")
            else:
                seen_uids[value] = f"{label} {name}"

    report = {
        "cache": CACHE.relative_to(ROOT).as_posix(),
        "cache_sha256": sha(CACHE),
        "archive_refs": archive_refs,
        "pairs": pairs,
        "expected": EXPECTED,
        "backup": backup_rows,
        "uids": uid_rows,
        "failures": failures,
    }
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for name, expected in EXPECTED.items():
        print(("PASS " if by_class.get(name) == [expected] else "FAIL ") + f"{name} -> {by_class.get(name)}")
    print(f"archive_refs={archive_refs} backup_files={len(backup_rows)}")
    for failure in failures:
        print("FAIL " + failure)
    print(f"CLASS_CACHE_VERIFY pass={1 if not failures else 0} fail={len(failures)}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
