"""Final summary JSON + group breakdown for the handoff."""
from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

OUT = Path(r"D:\godot game\星核旅人\项目归档\收尾_20261119")
ARCH_ROOT = Path(r"D:\godot game\星核旅人\非运行资料\历史测试与证据")

arch = list(csv.DictReader(open(OUT / "archive_manifest_20261119.csv", encoding="utf-8-sig")))
ren = list(csv.DictReader(open(OUT / "asset_rename_map.csv", encoding="utf-8-sig")))
scenes = list(csv.DictReader(open(OUT / "scenes_inventory.csv", encoding="utf-8-sig")))
audit = list(csv.DictReader(open(OUT / "asset_naming_audit.csv", encoding="utf-8-sig")))
verify = json.loads((OUT / "verify_report.json").read_text(encoding="utf-8"))

groups: Counter = Counter()
bytes_by_group: Counter = Counter()
for r in arch:
    groups[r["group"]] += 1
    bytes_by_group[r["group"]] += int(r["bytes"])

summary = {
    "generated": "2026-11-19",
    "project_root": r"D:\godot game\星核旅人\基础场景原型",
    "entry_scene": "res://scenes/level_01.tscn",
    "scene_inventory": {
        "total": len(scenes),
        "keep": sum(1 for r in scenes if r["decision"] == "KEEP"),
        "archive": sum(1 for r in scenes if r["decision"] == "ARCHIVE"),
    },
    "archive_move": {
        "archive_root": str(ARCH_ROOT),
        "files": len(arch),
        "bytes": sum(int(r["bytes"]) for r in arch),
        "by_group": {k: {"files": groups[k], "bytes": bytes_by_group[k]} for k in groups},
    },
    "rename": {
        "files": len(ren),
        "runtime_asset_payloads": len(audit),
        "renamed": sum(1 for r in audit if r["status"] == "RENAMED"),
        "compliant": sum(1 for r in audit if r["status"] == "COMPLIANT"),
        "retained_non_snake": sum(1 for r in audit if r["status"] == "RETAINED_NON_SNAKE"),
        "uids_preserved": True,
    },
    "verification": verify,
}
(OUT / "summary_20261119.json").write_text(
    json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8"
)
print(json.dumps(summary["scene_inventory"], ensure_ascii=False))
print(json.dumps(summary["archive_move"], ensure_ascii=False, indent=1))
print(json.dumps(summary["rename"], ensure_ascii=False))
print("verify problems:", len(verify["problems"]))
